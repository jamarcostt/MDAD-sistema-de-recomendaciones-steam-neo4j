# Steam Recommendation — Neo4j en Docker

## Estructura del proyecto

```
neo4j-steam/
├── docker-compose.yml        # Orquestación
├── .env                      # Contraseñas y configuración (NO subas al repo)
├── data/
│   └── csv/                  # ← Copia aquí tus 4 CSVs filtrados
├── neo4j/
│   ├── conf/neo4j.conf       # Configuración de memoria
│   └── init/init.sh          # Script de carga automática
└── scripts/
    └── load_data.cypher      # Queries de importación (referencia / manual)
```

---

## Puesta en marcha (primera vez)

### 1. Copia los CSVs filtrados

```bash
cp /ruta/a/tus/csvs/*.csv ./data/csv/
```

Deben estar estos cuatro archivos:
- `users_filtered.csv`
- `games_filtered.csv`
- `metadata_filtered.csv`
- `recommendations_filtered.csv`

### 2. Ajusta la contraseña en `.env`

Abre `.env` y cambia `SteamRecsPass2024!` por una contraseña segura.

### 3. Arranca los contenedores

```bash
docker compose up -d
```

Esto hace:
1. Descarga la imagen `neo4j:5.18.0` (primera vez ~500 MB)
2. Arranca el contenedor `steam-neo4j`
3. Cuando Neo4j está sano, arranca `steam-neo4j-init`
4. El init detecta que no hay datos → ejecuta la importación
5. El init se detiene solo al terminar

### 4. Monitoriza la importación

```bash
# Ver el progreso en tiempo real
docker logs -f steam-neo4j-init

# Ver logs de Neo4j
docker logs -f steam-neo4j
```

La importación tarda entre **15 y 45 minutos** según tu hardware.

### 5. Accede a Neo4j Browser

Una vez termine la importación:

- URL: http://localhost:7474
- Usuario: `neo4j`
- Contraseña: la que pusiste en `.env`

---

## Uso habitual (ya con datos cargados)

```bash
# Arrancar (los datos ya están en el volumen)
docker compose up -d neo4j

# Parar (sin borrar datos)
docker compose stop

# Parar y eliminar contenedores (datos intactos en volúmenes)
docker compose down

# Ver estado
docker compose ps
```

El contenedor `neo4j-init` sólo necesitas levantarlo la primera vez.
En arranques posteriores puedes ignorarlo o simplemente hacer:
```bash
docker compose up -d neo4j
```

---

## Borrar los datos y reimportar desde cero

```bash
# Elimina contenedores Y volúmenes (borra todos los datos del grafo)
docker compose down -v

# Vuelve a arrancar — la importación se ejecutará de nuevo
docker compose up -d
```

---

## Ajuste de memoria

Si tu máquina tiene menos de 16 GB de RAM, edita `.env`:

| RAM disponible | HEAP_INITIAL | HEAP_MAX | PAGECACHE |
|---------------|-------------|---------|----------|
| 8 GB          | 1g          | 2g      | 2g       |
| 16 GB         | 2g          | 4g      | 4g       |
| 32 GB         | 4g          | 8g      | 8g       |

---

## Consulta de recomendación

Desde Neo4j Browser, prueba la consulta híbrida con un usuario real:

```cypher
// Primero, encuentra un usuario con muchas recomendaciones
MATCH (u:User)-[r:RECOMMENDS]->()
WHERE r.is_recommended = true
RETURN u.user_id, count(r) AS total
ORDER BY total DESC
LIMIT 5;
```

Luego sustituye el ID en la consulta híbrida de `scripts/load_data.cypher`.
