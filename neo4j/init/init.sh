#!/bin/bash
# ── init.sh ─────────────────────────────────────────────────────────────────
# Ejecutado por el contenedor neo4j-init una sola vez al arrancar.
# Usa cypher-shell, que SÍ está disponible en la imagen oficial neo4j:5.x
# ─────────────────────────────────────────────────────────────────────────────

set -euo pipefail

NEO4J_HOST="neo4j"
NEO4J_BOLT_PORT="7687"
NEO4J_USER="neo4j"
NEO4J_PASS="${NEO4J_PASSWORD}"

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
log()  { echo -e "${GREEN}[INIT]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
err()  { echo -e "${RED}[ERR]${NC}  $*" >&2; }

# Wrapper de cypher-shell
cypher() {
    local query="$1"
    cypher-shell \
        --address "bolt://${NEO4J_HOST}:${NEO4J_BOLT_PORT}" \
        --username "$NEO4J_USER" \
        --password "$NEO4J_PASS" \
        --format plain \
        "$query" 2>/dev/null
}

# ── Paso 1: esperar a que Neo4j acepte conexiones Bolt ───────────────────────
log "Esperando a que Neo4j esté disponible en bolt://${NEO4J_HOST}:${NEO4J_BOLT_PORT}..."
MAX_WAIT=180
WAITED=0
until cypher "RETURN 1 AS ok" >/dev/null 2>&1; do
    if [ "$WAITED" -ge "$MAX_WAIT" ]; then
        err "Neo4j no respondió en ${MAX_WAIT}s. Revisa: docker logs steam-neo4j"
        exit 1
    fi
    sleep 5
    WAITED=$((WAITED + 5))
    log "  ...esperando (${WAITED}s)"
done
log "Neo4j disponible."

# ── Paso 2: comprobar si los datos ya están cargados ─────────────────────────
log "Comprobando si la base de datos ya tiene datos..."
USER_COUNT=$(cypher "MATCH (u:User) RETURN count(u) AS n;" \
    | grep -E '^[0-9]+$' | head -1 || echo "0")

if [ "${USER_COUNT:-0}" -gt "0" ]; then
    log "Base de datos ya cargada (${USER_COUNT} usuarios). Sin acción necesaria."
    log "Para reimportar: docker compose down -v && docker compose up -d"
    exit 0
fi

# ── Paso 3: verificar que los CSVs son accesibles desde Neo4j ────────────────
log "Verificando CSVs..."
CSVS=("users_filtered.csv" "games_filtered.csv" "metadata_filtered.csv" "recommendations_filtered.csv")
ALL_OK=true
for csv in "${CSVS[@]}"; do
    COUNT=$(cypher "LOAD CSV WITH HEADERS FROM 'file:///${csv}' AS row WITH row LIMIT 1 RETURN count(row) AS n;" \
        | grep -E '^[0-9]+$' | head -1 || echo "0")
    if [ "${COUNT:-0}" -eq "0" ]; then
        err "  No se pudo leer: ${csv}"
        err "  Asegurate de que esta en ./data/csv/ del proyecto"
        ALL_OK=false
    else
        log "  OK: ${csv}"
    fi
done
if [ "$ALL_OK" = false ]; then
    err "Faltan CSVs. Importacion cancelada."
    exit 1
fi

# ── Paso 4: importación por fases ────────────────────────────────────────────
log "================================================"
log "Iniciando importacion (puede tardar 15-45 min)..."
log "================================================"

log "[1/5] Creando indices y restricciones..."
cypher "
CREATE CONSTRAINT user_id_unique IF NOT EXISTS
FOR (u:User) REQUIRE u.user_id IS UNIQUE;
CREATE CONSTRAINT game_appid_unique IF NOT EXISTS
FOR (g:Game) REQUIRE g.app_id IS UNIQUE;
CREATE CONSTRAINT tag_name_unique IF NOT EXISTS
FOR (t:Tag) REQUIRE t.name IS UNIQUE;
"
log "  OK: indices creados"

log "[2/5] Importando usuarios..."
cypher "
LOAD CSV WITH HEADERS FROM 'file:///users_filtered.csv' AS row
CALL {
  WITH row
  MERGE (u:User {user_id: toInteger(row.user_id)})
  SET u.products = toInteger(row.products),
      u.reviews  = toInteger(row.reviews)
} IN TRANSACTIONS OF 50000 ROWS;
"
N=$(cypher "MATCH (u:User) RETURN count(u) AS n;" | grep -E '^[0-9]+$' | head -1 || echo "?")
log "  OK: ${N} usuarios"

log "[3/5] Importando juegos..."
cypher "
LOAD CSV WITH HEADERS FROM 'file:///games_filtered.csv' AS row
CALL {
  WITH row
  MERGE (g:Game {app_id: toInteger(row.app_id)})
  SET g.title          = row.title,
      g.date_release   = row.date_release,
      g.win            = toBoolean(row.win),
      g.mac            = toBoolean(row.mac),
      g.linux          = toBoolean(row.linux),
      g.rating         = row.rating,
      g.positive_ratio = toInteger(row.positive_ratio),
      g.user_reviews   = toInteger(row.user_reviews),
      g.price_final    = toFloat(row.price_final),
      g.price_original = toFloat(row.price_original),
      g.discount       = toFloat(row.discount),
      g.steam_deck     = toBoolean(row.steam_deck)
} IN TRANSACTIONS OF 50000 ROWS;
"
N=$(cypher "MATCH (g:Game) RETURN count(g) AS n;" | grep -E '^[0-9]+$' | head -1 || echo "?")
log "  OK: ${N} juegos"

log "[4/5] Importando tags y HAS_TAG..."
cypher "
LOAD CSV WITH HEADERS FROM 'file:///metadata_filtered.csv' AS row
CALL {
  WITH row
  MATCH (g:Game {app_id: toInteger(row.app_id)})
  WITH g, [tag IN split(row.tags, '|') WHERE trim(tag) <> ''] AS tags
  UNWIND tags AS tagName
  MERGE (t:Tag {name: trim(tagName)})
  MERGE (g)-[:HAS_TAG]->(t)
} IN TRANSACTIONS OF 10000 ROWS;
"
N=$(cypher "MATCH (t:Tag) RETURN count(t) AS n;" | grep -E '^[0-9]+$' | head -1 || echo "?")
log "  OK: ${N} tags"

log "[5/5] Importando RECOMMENDS (la fase mas larga)..."
cypher "
LOAD CSV WITH HEADERS FROM 'file:///recommendations_filtered.csv' AS row
CALL {
  WITH row
  MATCH (u:User {user_id: toInteger(row.user_id)})
  MATCH (g:Game {app_id: toInteger(row.app_id)})
  MERGE (u)-[r:RECOMMENDS]->(g)
  SET r.is_recommended  = toBoolean(row.is_recommended),
      r.hours           = toFloat(row.hours),
      r.hours_at_review = toFloat(row.hours_at_review),
      r.date            = date(row.date),
      r.funny           = toInteger(row.funny),
      r.helpful         = toInteger(row.helpful)
} IN TRANSACTIONS OF 100000 ROWS;
"
N=$(cypher "MATCH ()-[r:RECOMMENDS]->() RETURN count(r) AS n;" | grep -E '^[0-9]+$' | head -1 || echo "?")
log "  OK: ${N} relaciones RECOMMENDS"

log "Creando indice de fechas..."
cypher "
CREATE INDEX rec_date_idx IF NOT EXISTS
FOR ()-[r:RECOMMENDS]-() ON (r.date);
"

log "================================================"
log "Importacion completada."
log "  Browser: http://localhost:7474"
log "  Usuario: neo4j | Contrasena: (la del .env)"
log "================================================"
exit 0
