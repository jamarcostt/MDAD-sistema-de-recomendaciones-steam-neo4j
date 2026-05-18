#!/usr/bin/env pwsh
# =============================================================
#  load_data.ps1 - VERSION CON LOGGING EXTREMO
#  Levanta Neo4j en Docker y carga el dataset Steam completo.
# =============================================================

$NEO4J_USER     = $env:NEO4J_USER
$NEO4J_PASSWORD = $env:NEO4J_PASSWORD
$CONTAINER      = "neo4j-steam"
$CYPHER_SCRIPT  = "init_graph.cypher"
$LOG_FILE       = "neo4j_load_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"

# -- Funcion para logging dual (consola + archivo) -------------
function Log-Info  ($msg) { 
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMsg = "[$timestamp] [INFO]  $msg"
    Write-Host $logMsg -ForegroundColor Cyan
    Add-Content -Path $LOG_FILE -Value $logMsg
}
function Log-Ok    ($msg) { 
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMsg = "[$timestamp] [OK]    $msg"
    Write-Host $logMsg -ForegroundColor Green
    Add-Content -Path $LOG_FILE -Value $logMsg
}
function Log-Error ($msg) { 
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMsg = "[$timestamp] [ERROR] $msg"
    Write-Host $logMsg -ForegroundColor Red
    Add-Content -Path $LOG_FILE -Value $logMsg
}
function Log-Warn  ($msg) { 
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMsg = "[$timestamp] [WARN]  $msg"
    Write-Host $logMsg -ForegroundColor Yellow
    Add-Content -Path $LOG_FILE -Value $logMsg
}
function Log-Debug ($msg) { 
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMsg = "[$timestamp] [DEBUG] $msg"
    Write-Host $logMsg -ForegroundColor Gray
    Add-Content -Path $LOG_FILE -Value $logMsg
}

# -- Inicio del script ------------------------------------------
Log-Info "=========================================="
Log-Info "Iniciando carga de datos a Neo4j"
Log-Info "Log file: $LOG_FILE"
Log-Info "=========================================="

# -- Cargar .env si existe --------------------------------------
Log-Debug "Buscando archivo .env..."
if (Test-Path ".\.env") {
    Log-Debug "Archivo .env encontrado"
    Get-Content ".\.env" | ForEach-Object {
        if ($_ -match "^\s*([^#][^=]+)=(.+)$") {
            $name = $matches[1].Trim()
            $value = $matches[2].Trim()
            $value = $value -replace '^"|"$', '' -replace "^'|'$", ''
            [System.Environment]::SetEnvironmentVariable($name, $value)
            Log-Debug "Variable cargada: $name=********"
        }
    }
    $NEO4J_USER     = $env:NEO4J_USER
    $NEO4J_PASSWORD = $env:NEO4J_PASSWORD
} else {
    Log-Warn "No se encontro archivo .env"
}

if (-not $NEO4J_USER -or -not $NEO4J_PASSWORD) {
    Log-Error "No se encontraron NEO4J_USER o NEO4J_PASSWORD"
    Log-Error "Crea un archivo .env con esas variables"
    Log-Error "Ejemplo de .env:"
    Log-Error "  NEO4J_USER=neo4j"
    Log-Error "  NEO4J_PASSWORD=tu_password"
    exit 1
}
Log-Ok "Credenciales cargadas: usuario=$NEO4J_USER"

# -- 1. Comprobacion de archivos necesarios --------------------
Log-Info "Verificando archivos CSV..."
$required = @(
    ".\neo4j\import\recommendations_out.csv",
    ".\neo4j\import\games_out.csv",
    ".\neo4j\import\users_out.csv",
    ".\neo4j\import\metadata_out.csv"
)

foreach ($file in $required) {
    if (Test-Path $file) {
        $size = [math]::Round((Get-Item $file).Length / 1MB, 2)
        Log-Debug ("OK - $file ($size MB)")
    } else {
        Log-Debug ("MISSING - $file")
    }
}

$missing = $required | Where-Object { -not (Test-Path $_) }
if ($missing) {
    Log-Error "Faltan archivos CSV. Verifica que existen en la ruta correcta."
    Log-Error "Ruta esperada: .\neo4j\import\"
    exit 1
}
Log-Ok "Todos los CSVs encontrados"

# -- 2. Verificar Docker ----------------------------------------
Log-Info "Verificando Docker..."
try {
    $dockerVersion = docker --version 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "Docker no disponible"
    }
    Log-Ok "Docker disponible: $dockerVersion"
} catch {
    Log-Error "Docker no esta corriendo o no esta instalado"
    Log-Error "Asegurate de que Docker Desktop esta iniciado"
    exit 1
}

# -- 3. Crear carpetas necesarias ------------------------------
Log-Info "Creando estructura de carpetas..."
$folders = @(".\neo4j\data", ".\neo4j\logs", ".\neo4j\plugins", ".\neo4j\init")
foreach ($folder in $folders) {
    New-Item -ItemType Directory -Force -Path $folder | Out-Null
    Log-Debug "Carpeta asegurada: $folder"
}

# Copiar el script Cypher
if (Test-Path ".\$CYPHER_SCRIPT") {
    Copy-Item -Force ".\$CYPHER_SCRIPT" ".\neo4j\init\$CYPHER_SCRIPT"
    Log-Ok "Script Cypher copiado: $CYPHER_SCRIPT"
    
    # Mostrar primeras lineas del script para debug
    Log-Debug "Primeras 10 lineas del script Cypher:"
    Get-Content ".\neo4j\init\$CYPHER_SCRIPT" -TotalCount 10 | ForEach-Object {
        Log-Debug "  $_"
    }
    
    # Verificar que NO contiene :auto
    if (Select-String -Path ".\neo4j\init\$CYPHER_SCRIPT" -Pattern ":auto" -Quiet) {
        Log-Error "WARNING - El script Cypher contiene ':auto' - Esto NO es compatible con Neo4j 5.x"
        Log-Error "Debes eliminar ':auto' de la linea de LOAD CSV"
        Log-Error "Buscando lineas con ':auto':"
        Select-String -Path ".\neo4j\init\$CYPHER_SCRIPT" -Pattern ":auto" | ForEach-Object {
            Log-Error "  Linea $($_.LineNumber): $($_.Line)"
        }
        exit 1
    } else {
        Log-Ok "Script Cypher verificado - sin comandos :auto"
    }
} else {
    Log-Error "No se encuentra el script $CYPHER_SCRIPT"
    exit 1
}

# -- 4. Limpiar contenedores anteriores ------------------------
Log-Info "Limpiando contenedores anteriores..."
docker compose down -v 2>&1 | ForEach-Object { Log-Debug "  $_" }
Log-Ok "Contenedores limpiados"

# -- 5. Levantar el contenedor ---------------------------------
Log-Info "Levantando Neo4j con docker-compose..."
$composeUp = docker compose up -d 2>&1
$composeUp | ForEach-Object { Log-Debug "  $_" }

if ($LASTEXITCODE -ne 0) {
    Log-Error "docker compose up fallo"
    Log-Error "Salida del comando:"
    $composeUp | ForEach-Object { Log-Error $_ }
    exit 1
}
Log-Ok "Contenedor iniciado"

# -- 6. Esperar a que Neo4j este listo -------------------------
Log-Info "Esperando a que Neo4j este disponible..."
$maxRetries = 30
$retries = 0
$ready = $false

while ($retries -lt $maxRetries) {
    $retries++
    Log-Debug "Intento $retries/$maxRetries..."
    
    $result = docker exec $CONTAINER cypher-shell `
        -u $NEO4J_USER -p $NEO4J_PASSWORD `
        "RETURN 1" 2>&1
    
    Log-Debug "Codigo de salida: $LASTEXITCODE"
    Log-Debug "Salida del comando: $result"
    
    if ($LASTEXITCODE -eq 0) {
        $ready = $true
        Log-Ok "Neo4j esta listo despues de $retries intentos"
        break
    }
    
    # Mostrar logs del contenedor cada 5 intentos
    if ($retries % 5 -eq 0) {
        Log-Warn "Neo4j aun no responde. Ultimos logs:"
        docker logs --tail 10 $CONTAINER 2>&1 | ForEach-Object { Log-Warn "  $_" }
    }
    
    Start-Sleep -Seconds 5
}

if (-not $ready) {
    Log-Error "Neo4j no respondio despues de $maxRetries intentos"
    Log-Error "Logs completos del contenedor:"
    docker logs $CONTAINER 2>&1 | ForEach-Object { Log-Error "  $_" }
    exit 1
}

# -- 7. Ejecutar el script de carga ----------------------------
Log-Info "=========================================="
Log-Info "Ejecutando init_graph.cypher"
Log-Info "Esto puede tardar varios minutos..."
Log-Info "=========================================="

# Verificar que los archivos CSV estan montados correctamente
Log-Debug "Verificando montaje de volumenes..."
docker exec $CONTAINER ls -la /var/lib/neo4j/import/ 2>&1 | ForEach-Object { Log-Debug "  $_" }

# Guardar la salida completa
$cypherOutput = docker exec -i $CONTAINER cypher-shell `
    -u $NEO4J_USER -p $NEO4J_PASSWORD `
    --file "/var/lib/neo4j/init/$CYPHER_SCRIPT" 2>&1

# Mostrar cada linea de salida
$lineNumber = 0
$hasError = $false
$cypherOutput | ForEach-Object {
    $lineNumber++
    $line = $_
    if ($line -match "error|fail|exception|invalid|ne04j|Could not") {
        Log-Error "[CYPHER] $line"
        $hasError = $true
    } elseif ($line -match "warn") {
        Log-Warn "[CYPHER] $line"
    } elseif ($line -match "Created|Set|Added|Loaded") {
        Log-Ok "[CYPHER] $line"
    } elseif ($line -match "^[0-9]") {
        Log-Info "[CYPHER] $line"
    } elseif ($line.Trim() -ne "") {
        Log-Debug "[CYPHER] $line"
    }
}

if ($LASTEXITCODE -ne 0 -or $hasError) {
    Log-Error "=========================================="
    Log-Error "El script de carga FALLO con codigo: $LASTEXITCODE"
    Log-Error "=========================================="
    
    Log-Error "Logs completos del contenedor:"
    docker logs --tail 50 $CONTAINER 2>&1 | ForEach-Object { Log-Error "  $_" }
    
    Log-Error "=========================================="
    Log-Error "Verifica que los CSVs tengan las columnas correctas"
    Log-Error "Primeras lineas de cada CSV:"
    
    foreach ($csv in $required) {
        Log-Error "--- $csv ---"
        Get-Content $csv -TotalCount 3 | ForEach-Object { Log-Error "  $_" }
    }
    
    exit 1
}

# -- 8. Verificacion final -------------------------------------
Log-Info "=========================================="
Log-Info "Verificando nodos creados..."
$verification = docker exec $CONTAINER cypher-shell `
    -u $NEO4J_USER -p $NEO4J_PASSWORD `
    "MATCH (n) RETURN labels(n) AS tipo, count(n) AS total ORDER BY total DESC;"

Log-Info "Resultados:"
$verification | ForEach-Object { 
    if ($_ -match "^\+|^\||tipo|total") {
        Log-Info "  $_"
    } else {
        Log-Ok "  $_"
    }
}

Log-Ok "=========================================="
Log-Ok "CARGA COMPLETADA EXITOSAMENTE"
Log-Ok "=========================================="
Log-Info "Neo4j disponible en:"
Log-Info "  Browser : http://localhost:7474"
Log-Info "  Bolt    : bolt://localhost:7687"
Log-Info "  Usuario : $NEO4J_USER"
Log-Info "  Password: ********"
Log-Info "Log guardado en: $LOG_FILE"