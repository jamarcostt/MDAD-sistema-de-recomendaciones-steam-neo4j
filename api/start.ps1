# start.ps1 (versión que lee el .env)
Get-Content ../.env | ForEach-Object {
    if ($_ -match '^([^=]+)=(.*)$') {
        [Environment]::SetEnvironmentVariable($matches[1], $matches[2])
    }
}
mvn spring-boot:run