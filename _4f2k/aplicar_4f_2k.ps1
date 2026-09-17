$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "============================================================"
Write-Host " ETAPA 4F-2K - TIENDA / PRODUCTOS MULTICLUB"
Write-Host "============================================================"
Write-Host ""

$PayloadRoot = Join-Path $PSScriptRoot "payload"

$RepoRoot = Split-Path -Parent $PSScriptRoot

if (-not (Test-Path (Join-Path $RepoRoot "pubspec.yaml"))) {
    if (Test-Path (Join-Path $PSScriptRoot "pubspec.yaml")) {
        $RepoRoot = $PSScriptRoot
    } else {
        throw "No se encontro la raiz del proyecto Flutter. Extrae esta carpeta dentro de clubes_app_base."
    }
}

if (-not (Test-Path $PayloadRoot)) {
    throw "No se encontro la carpeta payload del paquete 4F-2K."
}

$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$BackupRoot = Join-Path $env:TEMP "clubes_app_base_4F_2K_backup_$timestamp"
New-Item -ItemType Directory -Force -Path $BackupRoot | Out-Null

$archivos = @(
    "lib\pantallas\pantalla_tienda.dart",
    "lib\pantallas\admin\pantalla_admin_tienda.dart",
    "lib\pantallas\admin\pantalla_admin_formulario_producto.dart",
    "lib\tusede\servicios\servicio_datos_club.dart",
    "lib\tusede\servicios\servicio_contenido_publico.dart",
    "functions_tusede\contenido_publico.js",
    "lib\main_prueba_tienda_admin_4f.dart",
    "lib\main_prueba_tienda_publica_4f.dart"
)

foreach ($rel in $archivos) {
    $origen = Join-Path $PayloadRoot $rel
    $destino = Join-Path $RepoRoot $rel

    if (-not (Test-Path $origen)) {
        throw "Falta archivo en payload: $rel"
    }

    if (Test-Path $destino) {
        $backup = Join-Path $BackupRoot $rel
        $backupDir = Split-Path -Parent $backup

        if (-not (Test-Path $backupDir)) {
            New-Item -ItemType Directory -Force -Path $backupDir | Out-Null
        }

        Copy-Item -Force $destino $backup
    }

    $destinoDir = Split-Path -Parent $destino

    if (-not (Test-Path $destinoDir)) {
        New-Item -ItemType Directory -Force -Path $destinoDir | Out-Null
    }

    Copy-Item -Force $origen $destino
    Write-Host "OK  $rel"
}

Write-Host ""
Write-Host "Instalacion 4F-2K aplicada."
Write-Host "Backup temporal:"
Write-Host $BackupRoot
Write-Host ""
Write-Host "NO hagas deploy ni commit todavia."
Write-Host "Siguiente control:"
Write-Host "  git status"
Write-Host "  git diff --check"
Write-Host "  node --check .\functions_tusede\contenido_publico.js"
Write-Host "  node --check .\functions_tusede\index.js"
Write-Host ""
