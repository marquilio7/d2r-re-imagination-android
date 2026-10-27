# instalar-android.ps1
# Instala el APK del port de Diablo II en un celular Android por adb y copia
# la carpeta data/ (archivos del juego) al almacenamiento interno de la app.
#
# Uso:
#   .\instalar-android.ps1 [-Apk ruta\al\app.apk] [-Data ruta\a\data] [-Launch] [-Uninstall]
#
# Requisitos:
#   - adb en el PATH (Android platform-tools) y un telefono conectado con
#     depuracion USB activada (autorizar la clave RSA en la pantalla del celular).
#   - La carpeta data/ con los archivos importados (2 GB aprox.).
#   - El telefono desbloqueado durante la copia.

param(
    [string]$Apk = "",
    [string]$Data = "",
    [switch]$Launch,
    [switch]$Uninstall
)

$ErrorActionPreference = "Stop"
$Pkg = "org.libsdl.app"
$Activity = "$Pkg/.SDLActivity"
$RemoteTmp = "/data/local/tmp/d2port-data"

function Fail($msg) { Write-Host "ERROR: $msg" -ForegroundColor Red; exit 1 }

# --- adb presente ---
if (-not (Get-Command adb -ErrorAction SilentlyContinue)) {
    Fail "adb no esta en el PATH. Instala Android platform-tools y agregalas al PATH."
}

# --- dispositivo ---
$devs = (adb devices) | Select-String -Pattern "\tdevice$"
if (-not $devs) {
    Write-Host "No hay telefono conectado. Conecta el USB, activa depuracion USB y autoriza la clave RSA." -ForegroundColor Yellow
    adb devices
    exit 1
}
Write-Host "Telefono conectado: $($devs -join ', ')" -ForegroundColor Green

# --- desinstalar ---
if ($Uninstall) {
    Write-Host "Desinstalando $Pkg..."
    adb uninstall $Pkg | Out-Null
    adb shell rm -rf $RemoteTmp 2>$null
    Write-Host "Listo."
    exit 0
}

# --- resolver APK ---
if ([string]::IsNullOrWhiteSpace($Apk)) {
    $candidates = @(
        (Join-Path $PSScriptRoot "app-debug.apk"),
        (Join-Path $PSScriptRoot "app-release.apk"),
        (Join-Path $PSScriptRoot "debug\app-debug.apk"),
        (Join-Path $PSScriptRoot "release\app-release.apk")
    )
    # tambien buscar recursivamente por si el script esta en la raiz del proyecto
    if (-not ($candidates | Where-Object { Test-Path $_ })) {
        $found = Get-ChildItem -Path $PSScriptRoot -Recurse -Filter "app-*.apk" -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($found) { $candidates = @($found.FullName) }
    }
    $Apk = $candidates | Where-Object { Test-Path $_ } | Select-Object -First 1
}
if ([string]::IsNullOrWhiteSpace($Apk) -or -not (Test-Path $Apk)) {
    Fail "No encontre el APK. Pasa -Apk ruta\al\app.apk"
}
Write-Host "APK: $Apk"

# --- resolver data ---
if ([string]::IsNullOrWhiteSpace($Data)) {
    $Data = Join-Path $PSScriptRoot "data"
    if (-not (Test-Path $Data)) {
        # buscar una carpeta data/ cerca del script
        $found = Get-ChildItem -Path $PSScriptRoot -Recurse -Directory -Filter "data" -ErrorAction SilentlyContinue |
            Where-Object { Test-Path (Join-Path $_.FullName "global\palette\act1") } | Select-Object -First 1
        if ($found) { $Data = $found.FullName }
    }
}
if (-not (Test-Path $Data)) {
    Fail "No encontre la carpeta data/. Pasa -Data ruta\a\data"
}
if (-not (Test-Path (Join-Path $Data "global\palette\act1"))) {
    Write-Host "Aviso: no veo data\global\palette\act1. La copia puede estar incompleta." -ForegroundColor Yellow
}
Write-Host "Data: $Data"

# --- instalar APK ---
Write-Host "Instalando APK..."
$installOut = adb install -r "$Apk" 2>&1
if ($LASTEXITCODE -ne 0 -and ($installOut -notmatch "Success")) {
    if ($installOut -match "INSTALL_FAILED_UPDATE_INCOMPATIBLE") {
        Write-Host "Firma incompatible: desinstalando la version anterior..." -ForegroundColor Yellow
        adb uninstall $Pkg | Out-Null
        $installOut = adb install "$Apk" 2>&1
    }
}
if ($LASTEXITCODE -ne 0 -and ($installOut -notmatch "Success")) {
    Write-Host $installOut
    if ($installOut -match "INSTALL_FAILED_USER_RESTRICTED|canceled by user") {
        Fail "La instalacion fue cancelada en el telefono. Confirma la instalacion en la pantalla del celular y volve a ejecutar."
    }
    Fail "Fallo la instalacion del APK."
}
Write-Host "APK instalado." -ForegroundColor Green

# --- verificar si run-as funciona (solo apps debuggeables) ---
$runAsOk = $true
adb shell run-as $Pkg echo ok 2>$null | Out-Null
if ($LASTEXITCODE -ne 0) { $runAsOk = $false }

if (-not $runAsOk) {
    Write-Host ""
    Write-Host "AVISO: la app instalada no es debuggeable (release). No se puede copiar data/ via run-as." -ForegroundColor Yellow
    Write-Host "Para copiar data/, instala la version debug (app-debug.apk) que es debuggeable." -ForegroundColor Yellow
    Write-Host "El APK release se instalo correctamente; copia data/ manualmente o usa la version debug." -ForegroundColor Yellow
    Write-Host ""
    try { Read-Host "Presiona Enter para cerrar..." } catch { }
    exit 0
}
$ErrorActionPreference = "Continue"
adb shell run-as $Pkg rm -rf files/data files/save 2>$null | Out-Null
$ErrorActionPreference = "Stop"
adb shell run-as $Pkg mkdir -p files/data files/save

# --- copiar data ---
Write-Host "Copiando data/ al telefono (2 GB aprox., puede tardar)..."
adb shell rm -rf $RemoteTmp 2>$null
adb push "$Data" $RemoteTmp 2>&1 | Select-Object -Last 1
if ($LASTEXITCODE -ne 0) { Fail "Fallo el adb push de data/." }

# el origen del push es $RemoteTmp (adb crea la subcarpeta solo si el destino ya existia; aqui no, asi que esta directo).
$ErrorActionPreference = "Continue"
adb shell run-as $Pkg rm -rf files/data 2>$null | Out-Null
adb shell run-as $Pkg mkdir -p files/data 2>$null | Out-Null
if (adb shell test -d "$RemoteTmp/data" 2>$null) {
    $srcPath = "$RemoteTmp/data/."
} else {
    $srcPath = "$RemoteTmp/."
}
adb shell run-as $Pkg cp -r $srcPath files/data/ 2>$null | Out-Null
$ErrorActionPreference = "Stop"
if ($LASTEXITCODE -ne 0) { Fail "Fallo la copia interna (run-as cp)." }

# verificar
$count = (adb shell run-as $Pkg find files/data -type f).Count
Write-Host "Archivos copiados: $count"
if ($count -lt 30000) {
    Write-Host "Aviso: se esperaban ~33899 archivos. Revisa la copia." -ForegroundColor Yellow
}

# limpiar temporal
adb shell rm -rf $RemoteTmp 2>$null

# --- lanzar ---
if ($Launch) {
    Write-Host "Lanzando el juego..."
    adb shell am start -n $Activity 2>&1 | Out-Null
}

Write-Host ""
Write-Host "Listo. El juego esta instalado. Abrelo desde el launcher del telefono." -ForegroundColor Green
Write-Host "Para ver el log: adb shell run-as $Pkg cat files/d2port.log" -ForegroundColor Gray
Write-Host ""
try { Read-Host "Presiona Enter para cerrar..." } catch { }