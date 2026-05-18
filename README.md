# MatchPlay — Neo4j en Docker

Sistema de recomendación de videojuegos de Steam basado en grafos con Neo4j.

---

## Estructura del proyecto

```
matchplay/
├── docker-compose.yml          # Orquestación del contenedor Neo4j
├── .env                        # Credenciales y configuración (NO subas al repo)
├── .gitignore
├── init_graph.cypher           # Script de carga del grafo (referencia / manual)
├── load_data.ps1               # Script PowerShell de despliegue automático (Windows)
└── neo4j/
    ├── data/                   # Datos persistentes del grafo (generado por Docker)
    ├── logs/                   # Logs de Neo4j (generado por Docker)
    ├── plugins/                # Plugins instalados (ej. APOC)
    ├── init/                   # Scripts de inicialización copiados automáticamente
    └── import/                 # ← Copia aquí tus 4 CSVs filtrados
        ├── recommendations_out.csv
        ├── games_out.csv
        ├── users_out.csv
        └── metadata_out.csv
```

---

## Requisitos previos

- [Docker Desktop](https://www.docker.com/products/docker-desktop/) corriendo
- PowerShell 7+ (Windows)
- Los 4 CSVs generados por `filter_steam_dataset.py`

---

## Puesta en marcha (primera vez)

### 1. Configura el archivo `.env`

Crea un archivo `.env` en la raíz del proyecto con este contenido:

```env
NEO4J_USER=neo4j
NEO4J_PASSWORD=TuPasswordSegura

JWT_SECRET=una-clave-larga-y-aleatoria-minimo-32-caracteres
JWT_EXPIRATION_MS=86400000

CORS_ALLOWED_ORIGIN=http://localhost:4200
```

### 2. Copia los CSVs filtrados

```powershell
copy recommendations_out.csv .\neo4j\import\
copy games_out.csv           .\neo4j\import\
copy users_out.csv           .\neo4j\import\
copy metadata_out.csv        .\neo4j\import\
```

### 3. Ejecuta el script de despliegue

```powershell
.\load_data.ps1
```

Este script hace todo automáticamente:
1. Verifica que los CSVs están en su sitio
2. Levanta el contenedor Neo4j vía `docker compose`
3. Espera a que Neo4j esté listo
4. Detecta si ya hay datos y pide confirmación antes de sobreescribir
5. Ejecuta `init_graph.cypher` con toda la carga del grafo
6. Muestra la verificación final de nodos creados

La carga de reviews puede tardar **2-5 minutos** según el hardware.

### 4. Accede a Neo4j Browser

```
URL:      http://localhost:7474
Usuario:  neo4j
Password: la que pusiste en .env
Bolt:     bolt://localhost:7687
```

---

## Verificación de la carga

Ejecuta esto en Neo4j Browser para confirmar que todo está correcto:

```cypher
MATCH (n) RETURN labels(n) AS tipo, count(n) AS total ORDER BY total DESC;
```

Resultado esperado:

| tipo     | total   |
|----------|---------|
| Review   | 1358215 |
| User     | 75302   |
| Game     | 29320   |
| Tag      | 441     |

---

## Uso habitual (ya con datos cargados)

```powershell
# Arrancar Neo4j (los datos persisten en el volumen)
docker compose up -d

# Parar sin borrar datos
docker compose stop

# Parar y eliminar contenedores (datos intactos)
docker compose down

# Ver estado
docker compose ps

# Ver logs en tiempo real
docker logs neo4j-steam --follow
```

---

## Borrar los datos y reimportar desde cero

```powershell
# Elimina contenedores Y volúmenes (borra todos los datos del grafo)
docker compose down -v

# Vuelve a desplegar desde cero
.\load_data.ps1
```

---

## Consultas de ejemplo

**Verificar relaciones del grafo:**
```cypher
MATCH (u:User)-[:WROTE]->(r:Review)-[:ABOUT]->(g:Game)
RETURN u.user_id, r.is_recommended, g.title
LIMIT 5;
```

**Recomendación basada en contenido** (juegos con tags similares a los que te gustan):
```cypher
MATCH (u:User {user_id: $id})-[:LIKES_TAG]->(t:Tag)<-[:HAS_TAG]-(g:Game)
RETURN g.title, count(t) AS coincidencias
ORDER BY coincidencias DESC LIMIT 10;
```

**Recomendación colaborativa** (juegos que juegan usuarios similares a ti):
```cypher
MATCH (u:User {user_id: $id})-[:SIMILAR_TO]->(other:User)
      -[:WROTE]->(:Review)-[:ABOUT]->(g:Game)
WHERE NOT (u)-[:WROTE]->(:Review)-[:ABOUT]->(g)
RETURN g.title, count(other) AS popularidad
ORDER BY popularidad DESC LIMIT 10;
```

---

## Stack del proyecto

| Capa       | Tecnología              |
|------------|-------------------------|
| Base de datos | Neo4j 5.18 + APOC    |
| Backend    | Java 21 + Spring Boot 3.5 |
| Frontend   | Angular 21.2 (zoneless) |
| Despliegue | Docker + Docker Compose |