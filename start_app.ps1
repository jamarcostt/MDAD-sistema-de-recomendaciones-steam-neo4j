# Guarda la ruta del directorio raíz actual
$rootDir = Get-Location

Write-Host "Iniciando el entorno de desarrollo..." -ForegroundColor Cyan

# ==========================================
# 1. ARRANCAR EL BACKEND (API)
# ==========================================
Write-Host "Preparando e iniciando el Backend (api)..." -ForegroundColor Yellow
Set-Location -Path "$rootDir\api"

# Lanza una nueva ventana de PowerShell
Start-Process powershell -ArgumentList "-NoExit -Command `"mvn clean compile -Dskipstyles; .\start.ps1`""

# Volvemos al directorio raíz
Set-Location -Path $rootDir


# ==========================================
# 2. ARRANCAR EL FRONTEND
# ==========================================
Write-Host "Iniciando el Frontend (matchplay-frontend)..." -ForegroundColor Yellow
Set-Location -Path "$rootDir\frontend\matchplay-frontend"

# Lanza una nueva ventana de PowerShell
Start-Process powershell -ArgumentList "-NoExit -Command `"ng serve -o`""

# Volvemos al directorio raíz final
Set-Location -Path $rootDir

Write-Host "Servicios lanzados. Se han abierto dos nuevas ventanas de terminal." -ForegroundColor Green