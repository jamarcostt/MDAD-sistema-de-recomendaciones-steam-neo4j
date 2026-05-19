$baseUrl = "http://localhost:8080/api"

# Definimos la bateria de pruebas: Nombre, Ruta y Metodo HTTP
$tests = @(
    # --- 1. PRUEBAS DE CATALOGO (GET simples y con parametros) ---
    @{ Name="Catalogo: Top Reviews (Defecto)"; Route="/games/top-reviews"; Method="GET" }
    @{ Name="Catalogo: Top Reviews (Limit 5)"; Route="/games/top-reviews?limit=5"; Method="GET" }
    @{ Name="Catalogo: Top Rated"; Route="/games/top-rated"; Method="GET" }
    @{ Name="Catalogo: Distribucion Precios"; Route="/games/price-distribution"; Method="GET" }
    @{ Name="Catalogo: Busqueda exacta Tag"; Route="/games/by-tag?tagName=Action&limit=2"; Method="GET" }
    @{ Name="Catalogo: Busqueda texto"; Route="/games/search?q=counter"; Method="GET" }
    
    # --- 2. PRUEBAS DE ETIQUETAS ---
    @{ Name="Tags: Top 10 Etiquetas"; Route="/tags/top?limit=10"; Method="GET" }

    # --- 3. PRUEBAS DE BIBLIOTECA (Escritura POST) ---
    @{ Name="Usuario: Anadir CS:GO (304930)"; Route="/user/library/304930"; Method="POST" }
    @{ Name="Usuario: Anadir PUBG (433850)"; Route="/user/library/433850"; Method="POST" }
    @{ Name="Usuario: Ver Biblioteca"; Route="/user/library"; Method="GET" }

    # --- 4. PRUEBAS DE ANALISIS (Dependen de tener juegos en la biblioteca) ---
    @{ Name="Analisis: Distribucion Tags"; Route="/user/tag-distribution"; Method="GET" }
    @{ Name="Analisis: Comparativa Precios"; Route="/user/price-comparison"; Method="GET" }
    @{ Name="Analisis: Comparativa Ratio"; Route="/user/ratio-comparison"; Method="GET" }
    @{ Name="Analisis: Tags Faltantes"; Route="/user/missing-tags?limit=3"; Method="GET" }

    # --- 5. PRUEBAS DE RECOMENDACIONES ---
    @{ Name="Recomendacion: Contenido"; Route="/user/recommendations/content?limit=5"; Method="GET" }
    @{ Name="Recomendacion: Colaborativa"; Route="/user/recommendations/collaborative?limit=5"; Method="GET" }
    @{ Name="Recomendacion: Hibrida"; Route="/user/recommendations/hybrid?limit=5"; Method="GET" }

    # --- 6. PRUEBAS DE GRAFOS (D3.js) ---
    @{ Name="Grafo: Juegos Similares"; Route="/user/graph/similar-games"; Method="GET" }
    @{ Name="Grafo: Tags Relacionadas"; Route="/user/graph/related-tags"; Method="GET" }

    # --- 7. PRUEBAS DE LIMPIEZA (Borrado DELETE) ---
    @{ Name="Usuario: Eliminar CS:GO (304930)"; Route="/user/library/304930"; Method="DELETE" }
    @{ Name="Usuario: Eliminar PUBG (433850)"; Route="/user/library/433850"; Method="DELETE" }
)

Write-Host "=================================================" -ForegroundColor Cyan
Write-Host " INICIANDO BATERIA DE PRUEBAS FUNCIONALES (MODO VERBOSO)" -ForegroundColor Cyan
Write-Host "=================================================" -ForegroundColor Cyan
Write-Host ""

$passed = 0
$failed = 0
$testNumber = 1

foreach ($test in $tests) {
    $url = "$baseUrl$($test.Route)"
    $method = $test.Method
    $name = $test.Name
    
    Write-Host "-------------------------------------------------" -ForegroundColor Gray
    Write-Host "Prueba [$testNumber/$($tests.Count)]" -ForegroundColor Yellow
    Write-Host "Nombre   : $name" -ForegroundColor White
    Write-Host "Peticion : $method $url" -ForegroundColor White
    Write-Host "Ejecutando..." -ForegroundColor DarkGray
    
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    
    try {
        # Ejecutamos la peticion
        $response = Invoke-WebRequest -Uri $url -Method $method -UseBasicParsing -ErrorAction Stop
        $stopwatch.Stop()
        
        $statusCode = $response.StatusCode
        $contentLength = $response.Content.Length
        $executionTime = $stopwatch.ElapsedMilliseconds
        
        Write-Host "Latencia : $executionTime ms" -ForegroundColor DarkCyan
        
        # Validamos que devuelva 200 OK y que el contenido no este vacio
        if ($statusCode -eq 200 -and $contentLength -gt 2) {
            Write-Host "[PASS] Exito. Codigo: $statusCode | Tamano: $contentLength bytes" -ForegroundColor Green
            
            # Muestra un resumen del payload devuelto
            $preview = $response.Content
            if ($preview.Length -gt 250) {
                $preview = $preview.Substring(0, 250) + "... [TRUNCADO]"
            }
            Write-Host "Payload  : $preview" -ForegroundColor DarkGray
            
            $passed++
        } else {
            Write-Host "[FAIL] Respuesta vacia o codigo de estado inusual." -ForegroundColor Red
            Write-Host "Codigo Estado: $statusCode" -ForegroundColor Red
            Write-Host "Tamano Cuerpo: $contentLength bytes" -ForegroundColor Red
            Write-Host "Cuerpo Integro: $($response.Content)" -ForegroundColor DarkRed
            $failed++
        }
    } catch {
        $stopwatch.Stop()
        Write-Host "[FAIL] Ocurrio una excepcion HTTP." -ForegroundColor Red
        Write-Host "Tiempo antes del fallo: $($stopwatch.ElapsedMilliseconds) ms" -ForegroundColor DarkRed
        Write-Host "Excepcion: $($_.Exception.Message)" -ForegroundColor Red
        
        # Intenta extraer el cuerpo del error lanzado por Spring Boot (util para errores 500 y 400)
        if ($_.Exception.Response) {
            try {
                $errorStream = $_.Exception.Response.GetResponseStream()
                $reader = New-Object System.IO.StreamReader($errorStream)
                $responseBody = $reader.ReadToEnd()
                Write-Host "Detalle del Servidor:" -ForegroundColor Magenta
                Write-Host $responseBody -ForegroundColor DarkRed
            } catch {
                Write-Host "No se pudo extraer el cuerpo del error." -ForegroundColor DarkGray
            }
        }
        $failed++
    }
    
    $testNumber++
    Write-Host ""
}

Write-Host "=================================================" -ForegroundColor Cyan
Write-Host " RESULTADOS FINALES:"
Write-Host " Pruebas ejecutadas: $($tests.Count)"
Write-Host " Exitosos: $passed" -ForegroundColor Green

if ($failed -gt 0) {
    Write-Host " Fallidos: $failed" -ForegroundColor Red
} else {
    Write-Host " Fallidos: $failed" -ForegroundColor Green
}
Write-Host "=================================================" -ForegroundColor Cyan