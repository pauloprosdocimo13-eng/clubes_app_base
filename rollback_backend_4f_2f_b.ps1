$ErrorActionPreference = "Stop"

$repo = Get-Location
$index = Join-Path $repo "functions_tusede\index.js"
$backup = "$index.antes_4f_2f_b.bak"

if (-not (Test-Path $backup)) {
    throw "No se encontro el backup $backup"
}

Copy-Item $backup $index -Force
Write-Host "index.js restaurado desde el backup 4F-2F-B." -ForegroundColor Green
