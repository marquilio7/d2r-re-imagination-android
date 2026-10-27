# compilar.ps1
# Compila LAS DOS versiones de una vez: PC (Windows) y Android (APK).
# Si hay un telefono conectado con el juego ya instalado, actualiza el APK
# conservando la carpeta data/ (no la vuelve a copiar).
#
# Uso:
#   .\compilar.ps1                 compila PC + Android (debug)
#   .\compilar.ps1 -Release        idem, Android en release
#   .\compilar.ps1 -NoInstall      solo compila, no toca el telefono
#   .\compilar.ps1 -Data D:\J\d2port\data
#
# La version de red es fija (d2port-android-0.8.4) en las dos, asi siempre
# pueden jugar juntas por LAN.

param(
    [switch]$Release,
    [switch]$NoInstall,
    [string]$Data = ""
)

$ErrorActionPreference = "Stop"
$root = $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($root)) { $root = (Get-Location).Path }
# por si se copia a dist/: la fuente esta en la carpeta padre
if (-not (Test-Path (Join-Path $root "CMakeLists.txt"))) {
    $parent = Split-Path $root -Parent
    if (Test-Path (Join-Path $parent "CMakeLists.txt")) { $root = $parent }
}

function Line($t) { Write-Host ""; Write-Host "==== $t ====" -ForegroundColor Cyan }

# --- 1/2  PC ---
Line "1/2  PC (Windows)"
$pcArgs = @{ NoPause = $true }
if (-not [string]::IsNullOrWhiteSpace($Data)) { $pcArgs.Data = $Data }
& (Join-Path $root "compilar-pc.ps1") @pcArgs
if ($LASTEXITCODE -ne 0) { throw "Fallo la compilacion de PC." }

# --- 2/2  Android ---
Line "2/2  Android (APK)"
$androidArgs = @{ NoPause = $true }
if ($Release) { $androidArgs.Release = $true }
if (-not [string]::IsNullOrWhiteSpace($Data)) { $androidArgs.Data = $Data }
& (Join-Path $root "compilar-android.ps1") @androidArgs
if ($LASTEXITCODE -ne 0) { throw "Fallo la compilacion de Android." }

# --- instalar el APK nuevo (si el telefono ya lo tiene) ---
# Solo el debug: es debuggeable (permite copiar data/) y tiene la misma firma
# que la instalacion actual. El release tiene otra firma y no es debuggeable.
if (-not $NoInstall -and -not $Release) {
    $adb = Get-Command adb -ErrorAction SilentlyContinue
    if ($adb) {
        $devs = (adb devices) | Select-String -Pattern "\tdevice$"
        if ($devs) {
            $installed = (adb shell pm path org.libsdl.app 2>$null) -match "package:"
            if ($installed) {
                Line "Instalando el APK nuevo en el telefono (data/ se conserva)"
                $instArgs = @{ SkipData = $true; NoPause = $true; Apk = (Join-Path $root "dist\app-debug.apk") }
                & (Join-Path $root "instalar-android.ps1") @instArgs
            } else {
                Write-Host "El telefono no tiene el juego instalado: no lo instalo solo (faltaria data/)." -ForegroundColor Yellow
                Write-Host "Usa .\instalar-android.ps1 -Data <ruta\data> para la primera instalacion." -ForegroundColor Yellow
            }
        } else {
            Write-Host "No hay telefono conectado: solo compile." -ForegroundColor Yellow
        }
    } else {
        Write-Host "adb no esta en el PATH: solo compile." -ForegroundColor Yellow
    }
}

Line "Listo"
Write-Host "PC:      $root\dist\windows\d2port.exe" -ForegroundColor Green
Write-Host "Android: $root\dist\app-debug.apk" -ForegroundColor Green
Write-Host ""
try { Read-Host "Presiona Enter para cerrar..." } catch { }
