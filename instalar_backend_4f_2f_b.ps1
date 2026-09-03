$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "==============================================="
Write-Host " TuSede - Instalador backend 4F-2F-B"
Write-Host "==============================================="
Write-Host ""

$repo = Get-Location
$funcDir = Join-Path $repo "functions_tusede"
$index = Join-Path $funcDir "index.js"
$modulo = Join-Path $funcDir "carnet_publico.js"

if (-not (Test-Path $funcDir)) {
    throw "No existe functions_tusede. Ejecuta este script desde la raiz del repositorio."
}

if (-not (Test-Path $index)) {
    throw "No existe functions_tusede\index.js."
}

if (-not (Test-Path $modulo)) {
    throw "Falta functions_tusede\carnet_publico.js. Copialo antes de ejecutar este script."
}

$linea = 'Object.assign(module.exports, require("./carnet_publico"));'
$contenido = Get-Content $index -Raw

if ($contenido.Contains($linea)) {
    Write-Host "El backend 4F-2F-B ya esta integrado en index.js." -ForegroundColor Yellow
    exit 0
}

$backup = "$index.antes_4f_2f_b.bak"
Copy-Item $index $backup -Force

Add-Content -Path $index -Value ""
Add-Content -Path $index -Value "// ============================================================"
Add-Content -Path $index -Value "// ETAPA 4F-2F-B - Carnet publico controlado"
Add-Content -Path $index -Value "// ============================================================"
Add-Content -Path $index -Value $linea

Write-Host "OK: index.js actualizado." -ForegroundColor Green
Write-Host "Backup: $backup" -ForegroundColor Green
Write-Host ""
Write-Host "Siguiente paso:"
Write-Host "firebase deploy --only functions:buscarCarnetPublico --project tu-sede-app --config firebase.tusede.json"
