#!/usr/bin/env pwsh
# =============================================================
#  load_data.ps1
#  Levanta Neo4j en Docker y carga el dataset Steam completo.
#
#  USO:
#    .\load_data.ps1
#
#  REQUISITOS:
#    - Docker Desktop corriendo
#    - Los cuatro CSVs en .\neo4j\import\
#        recommendations_out.csv
#        games_out.csv
#        users_out.csv
#        metadata_out.csv
# =============================================================

$NEO4J_USER     = $env:NEO4J_USER
$NEO4J_PASSWORD = $env:NEO4J_PASSWORD
$CONTAINER      = "neo4j-steam"
$CYPHER_SCRIPT  = "init_graph.cypher"

# ── Cargar .env si existe ─────────────────────────────────────
if (Test-Path ".\.env") {
    Get-Content ".\.env" | ForEach-Object {
        if ($_ -match "^\s*([^#][^=]+)=(.+)$") {
            [System.Environment]::SetEnvironmentVariable($matches[1].Trim(), $matches[2].Trim())
        }
    }
    $NEO4J_USER     = $env:NEO4J_USER
    $NEO4J_PASSWORD = $env:NEO4J_PASSWORD
}

if (-not $NEO4J_USER -or -not $NEO4J_PASSWORD) {
    Err "No se encontraron NEO4J_USER o NEO4J_PASSWORD. Crea un archivo .env con esas variables."
    exit 1
}

# ── Colores para la consola ───────────────────────────────────
function Info  ($msg) { Write-Host "[INFO]  $msg" -ForegroundColor Cyan    }
function Ok    ($msg) { Write-Host "[OK]    $msg" -ForegroundColor Green   }
function Err   ($msg) { Write-Host "[ERROR] $msg" -ForegroundColor Red     }
function Warn  ($msg) { Write-Host "[WARN]  $msg" -ForegroundColor Yellow  }

# ── 1. Comprobación de archivos necesarios ────────────────────
Info "Verificando archivos CSV..."
$required = @(
    ".\neo4j\import\recommendations_out.csv",
    ".\neo4j\import\games_out.csv",
    ".\neo4j\import\users_out.csv",
    ".\neo4j\import\metadata_out.csv"
)
$missing = $required | Where-Object { -not (Test-Path $_) }
if ($missing) {
    Err "Faltan los siguientes archivos:"
    $missing | ForEach-Object { Write-Host "  · $_" -ForegroundColor Red }
    exit 1
}
Ok "Todos los CSVs encontrados."

# ── 2. Crear carpetas necesarias ──────────────────────────────
Info "Creando estructura de carpetas..."
@(".\neo4j\data", ".\neo4j\logs", ".\neo4j\plugins", ".\neo4j\init") |
    ForEach-Object { New-Item -ItemType Directory -Force -Path $_ | Out-Null }

# Copiar el script Cypher al volumen de init
Copy-Item -Force ".\$CYPHER_SCRIPT" ".\neo4j\init\$CYPHER_SCRIPT"
Ok "Carpetas listas."

# ── 3. Levantar el contenedor ─────────────────────────────────
Info "Levantando Neo4j con docker-compose..."
docker compose up -d

if ($LASTEXITCODE -ne 0) {
    Err "docker compose up falló. Comprueba que Docker Desktop está corriendo."
    exit 1
}
Ok "Contenedor iniciado."

# ── 4. Esperar a que Neo4j esté listo ─────────────────────────
Info "Esperando a que Neo4j esté disponible (puede tardar ~30s)..."
$maxRetries = 30
$retries    = 0
$ready      = $false

while ($retries -lt $maxRetries) {
    $result = docker exec $CONTAINER cypher-shell `
        -u $NEO4J_USER -p $NEO4J_PASSWORD `
        "RETURN 1" 2>&1

    if ($LASTEXITCODE -eq 0) {
        $ready = $true
        break
    }
    $retries++
    Write-Host "  Intento $retries/$maxRetries..." -ForegroundColor DarkGray
    Start-Sleep -Seconds 5
}

if (-not $ready) {
    Err "Neo4j no respondió a tiempo. Revisa los logs con: docker logs $CONTAINER"
    exit 1
}
Ok "Neo4j está listo."

# ── 5. Comprobar si la BD ya tiene datos ──────────────────────
Info "Comprobando si la base de datos ya tiene datos..."
$count = docker exec $CONTAINER cypher-shell `
    -u $NEO4J_USER -p $NEO4J_PASSWORD `
    "MATCH (n) RETURN count(n) AS total" `
    --format plain 2>&1 | Select-Object -Last 1

if ($count -and [int]$count -gt 0) {
    Warn "La base de datos ya contiene $count nodos."
    $confirm = Read-Host "¿Quieres volver a cargar los datos? Esto BORRARÁ todo. (s/N)"
    if ($confirm -ne "s" -and $confirm -ne "S") {
        Info "Carga cancelada. Neo4j sigue corriendo en http://localhost:7474"
        exit 0
    }
    Info "Borrando datos existentes..."
    docker exec $CONTAINER cypher-shell `
        -u $NEO4J_USER -p $NEO4J_PASSWORD `
        "MATCH (n) CALL { WITH n DETACH DELETE n } IN TRANSACTIONS OF 10000 ROWS;"
    Ok "Base de datos limpiada."
}

# ── 6. Ejecutar el script de carga ────────────────────────────
Info "Ejecutando init_graph.cypher (esto puede tardar varios minutos)..."
docker exec -i $CONTAINER cypher-shell `
    -u $NEO4J_USER -p $NEO4J_PASSWORD `
    --file "/var/lib/neo4j/init/$CYPHER_SCRIPT"

if ($LASTEXITCODE -ne 0) {
    Err "El script de carga falló. Revisa los logs con: docker logs $CONTAINER"
    exit 1
}
Ok "Dataset cargado correctamente."

# ── 7. Verificación final ─────────────────────────────────────
Info "Verificando nodos creados..."
docker exec $CONTAINER cypher-shell `
    -u $NEO4J_USER -p $NEO4J_PASSWORD `
    "MATCH (n) RETURN labels(n) AS tipo, count(n) AS total ORDER BY total DESC;"

Write-Host ""
Ok "Todo listo. Neo4j disponible en:"
Write-Host "  Browser : http://localhost:7474" -ForegroundColor White
Write-Host "  Bolt    : bolt://localhost:7687"  -ForegroundColor White
Write-Host "  Usuario : $NEO4J_USER"            -ForegroundColor White
Write-Host "  Password: $NEO4J_PASSWORD"         -ForegroundColor White
