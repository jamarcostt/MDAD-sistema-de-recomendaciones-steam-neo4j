// ── load_data.cypher ────────────────────────────────────────────────────────
// Script de importación completo del dataset de Steam.
// El init.sh lo ejecuta automáticamente al arrancar el contenedor.
// También puedes pegarlo manualmente en Neo4j Browser si lo necesitas.
// ────────────────────────────────────────────────────────────────────────────


// ── 1. RESTRICCIONES E ÍNDICES ───────────────────────────────────────────────
// Deben crearse ANTES de importar datos. Crean el índice automáticamente.

CREATE CONSTRAINT user_id_unique IF NOT EXISTS
FOR (u:User) REQUIRE u.user_id IS UNIQUE;

CREATE CONSTRAINT game_appid_unique IF NOT EXISTS
FOR (g:Game) REQUIRE g.app_id IS UNIQUE;

CREATE CONSTRAINT tag_name_unique IF NOT EXISTS
FOR (t:Tag) REQUIRE t.name IS UNIQUE;


// ── 2. NODOS USER ────────────────────────────────────────────────────────────
// Fuente: users_filtered.csv
// Columnas: user_id, products, reviews

LOAD CSV WITH HEADERS FROM 'file:///users_filtered.csv' AS row
CALL {
  WITH row
  MERGE (u:User {user_id: toInteger(row.user_id)})
  SET u.products = toInteger(row.products),
      u.reviews  = toInteger(row.reviews)
} IN TRANSACTIONS OF 50000 ROWS;


// ── 3. NODOS GAME ────────────────────────────────────────────────────────────
// Fuente: games_filtered.csv
// Columnas: app_id, title, date_release, win, mac, linux, rating,
//           positive_ratio, user_reviews, price_final, price_original,
//           discount, steam_deck

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


// ── 4. NODOS TAG + RELACIONES HAS_TAG ────────────────────────────────────────
// Fuente: metadata_filtered.csv
// Columnas: app_id, description, tags   (tags separados por '|')
// Crea un nodo Tag por cada tag único y lo conecta al juego.

LOAD CSV WITH HEADERS FROM 'file:///metadata_filtered.csv' AS row
CALL {
  WITH row
  MATCH (g:Game {app_id: toInteger(row.app_id)})
  WITH g, [tag IN split(row.tags, '|') WHERE trim(tag) <> ''] AS tags
  UNWIND tags AS tagName
  MERGE (t:Tag {name: trim(tagName)})
  MERGE (g)-[:HAS_TAG]->(t)
} IN TRANSACTIONS OF 10000 ROWS;


// ── 5. RELACIONES RECOMMENDS ─────────────────────────────────────────────────
// Fuente: recommendations_filtered.csv
// Columnas: app_id, helpful, funny, date, is_recommended,
//           hours, hours_at_review, review_id, user_id
// Es el archivo más grande — lotes de 100k filas.

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


// ── 6. ÍNDICE POST-IMPORTACIÓN ───────────────────────────────────────────────
// Lo creamos DESPUÉS de la importación para no ralentizar las escrituras.

CREATE INDEX rec_date_idx IF NOT EXISTS
FOR ()-[r:RECOMMENDS]-() ON (r.date);


// ── 7. VERIFICACIÓN FINAL ────────────────────────────────────────────────────
// Ejecuta esto para confirmar que todo se importó correctamente.

MATCH (u:User)              RETURN 'Users'      AS tipo, count(u) AS total UNION ALL
MATCH (g:Game)              RETURN 'Games'      AS tipo, count(g) AS total UNION ALL
MATCH (t:Tag)               RETURN 'Tags'       AS tipo, count(t) AS total UNION ALL
MATCH ()-[r:RECOMMENDS]->() RETURN 'RECOMMENDS' AS tipo, count(r) AS total UNION ALL
MATCH ()-[r:HAS_TAG]->()    RETURN 'HAS_TAG'    AS tipo, count(r) AS total;
