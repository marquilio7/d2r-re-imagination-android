# compilar-android.ps1
# Compila el port para Android (APK) con el toolchain de MSYS2/Windows.
# Despues de compilar, puede instalar el APK en un telefono conectado y copiar
# la carpeta data/ (igual que instalar-android.ps1).
#
# Uso:
#   .\compilar-android.ps1 [-Release] [-Install] [-Data ruta\data] [-Jdk RUTA] [-Sdk RUTA] [-Ndk RUTA]
param(
    [switch]$Release,
    [switch]$Install,
    [string]$Data = "",
    [string]$Jdk = "D:\J\tools\jdk17",
    [string]$Sdk = "C:\Users\yo\AppData\Local\Android\Sdk",
    [string]$Ndk = "C:\Users\yo\AppData\Local\Android\Sdk\ndk\25.1.8937393"
)

$ErrorActionPreference = "Stop"
$root = $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($root)) { $root = (Get-Location).Path }
# detectar raiz del codigo
if (-not (Test-Path (Join-Path $root "CMakeLists.txt"))) {
    $parent = Split-Path $root -Parent
    if (Test-Path (Join-Path $parent "CMakeLists.txt")) { $root = $parent }
}

# --- verificar toolchain ---
if (-not (Test-Path (Join-Path $Jdk "bin\java.exe"))) { throw "No encontre JDK en $Jdk. Pasa -Jdk." }
if (-not (Test-Path $Sdk)) { throw "No encontre Android SDK en $Sdk. Pasa -Sdk." }
if (-not (Test-Path $Ndk)) { throw "No encontre NDK en $Ndk. Pasa -Ndk." }

$env:JAVA_HOME = $Jdk
$env:ANDROID_HOME = $Sdk
$env:ANDROID_NDK_HOME = $Ndk
$env:PATH = "$Jdk\bin;$env:PATH"

# --- crear local.properties si no existe ---
$lp = Join-Path $root "android\local.properties"
if (-not (Test-Path $lp)) {
    "sdk.dir=$($Sdk -replace '\\','/')" | Set-Content $lp -Encoding ASCII
    Write-Host "Creado: $lp"
}

# --- junction para ndk-build (paths sin ..) ---
$portJunction = Join-Path $root "android\app\jni\port"
if (-not (Test-Path $portJunction)) {
    if (Test-Path "android\app\jni\port") { } # already
    $src = $root
    cmd /c "mklink /J `"$portJunction`" `"$src`"" 2>&1 | Out-Null
    if (Test-Path $portJunction) { Write-Host "Junction creado: $portJunction" }
}

# --- compilar ---
$gradle = Join-Path $root "android\gradlew.bat"
if (-not (Test-Path $gradle)) { throw "No encontre gradlew.bat en $root\android" }

$task = if ($Release) { "assembleRelease" } else { "assembleDebug" }
Write-Host "Compilando Android ($task)..." -ForegroundColor Cyan
Push-Location (Join-Path $root "android")
& $gradle $task
$ec = $LASTEXITCODE
Pop-Location
if ($ec -ne 0) { throw "La compilacion Android fallo (exit $ec)." }

$apkSub = if ($Release) { "release" } else { "debug" }
$apkName = if ($Release) { "app-release.apk" } else { "app-debug.apk" }
$apk = Join-Path $root "android\app\build\outputs\apk\$apkSub\$apkName"
if (-not (Test-Path $apk)) { throw "No encontre el APK en $apk" }
Write-Host "APK listo: $apk" -ForegroundColor Green

# copiar a dist/ si existe
$dist = Join-Path $root "dist"
if (Test-Path $dist) {
    Copy-Item $apk (Join-Path $dist $apkName) -Force
    Write-Host "Copiado a: $dist\$apkName" -ForegroundColor Green
}

# --- instalar en telefono (opcional) ---
if ($Install) {
    Write-Host ""
    Write-Host "Instalando en telefono conectado..." -ForegroundColor Cyan
    adb devices | Select-String -Pattern "\tdevice$" | Out-Null
    $devs = (adb devices) | Select-String -Pattern "\tdevice$"
    if (-not $devs) {
        Write-Host "No hay telefono conectado. Salteo la instalacion." -ForegroundColor Yellow
    } else {
        adb install -r $apk | Select-Object -Last 2
        Write-Host "APK instalado." -ForegroundColor Green

        # detectar data/
        if ([string]::IsNullOrWhiteSpace($Data)) {
            $candidates = @()
            foreach ($p in @(
                (Join-Path $root "data"),
                "D:\J\d2port\data",
                "C:\J\Diablo II\data"
            )) {
                if (Test-Path (Join-Path $p "global\palette\act1")) { $candidates += $p }
            }
            if ($candidates.Count -gt 0) {
                Write-Host "Carpetas data/ detectadas:"
                for ($i = 0; $i -lt $candidates.Count; $i++) { Write-Host "  [$($i+1)] $($candidates[$i])" }
                $sel = "1"
                try { $s = Read-Host "Elegi una opcion (Enter=1)"; if ($s) { $sel = $s } } catch { }
                if ($sel -match '^\d+$' -and [int]$sel -ge 1 -and [int]$sel -le $candidates.Count) {
                    $Data = $candidates[[int]$sel - 1]
                }
            }
        }

        if ($Data -and (Test-Path (Join-Path $Data "global\palette\act1"))) {
            Write-Host "Copiando data/ al telefono (puede tardar)..." -ForegroundColor Cyan
            adb shell run-as org.libsdl.app rm -rf files/data files/save 2>$null
            adb shell run-as org.libsdl.app mkdir -p files/data files/save
            adb shell rm -rf /data/local/tmp/d2port-data 2>$null
            adb push $Data /data/local/tmp/d2port-data 2>&1 | Select-Object -Last 1
            adb shell run-as org.libsdl.app rm -rf files/data
            adb shell run-as org.libsdl.app mkdir -p files/data
            adb shell run-as org.libsdl.app cp -r /data/local/tmp/d2port-data/data files/data
            adb shell rm -rf /data/local/tmp/d2port-data 2>$null
            $count = (adb shell run-as org.libsdl.app find files/data -type f).Count
            Write-Host "Archivos copiados: $count" -ForegroundColor Green
            adb shell am start -n org.libsdl.app/.SDLActivity 2>&1 | Out-Null
        }
    }
}

Write-Host ""
Write-Host "Compilacion Android terminada." -ForegroundColor Green
Write-Host ""
Read-Host "Presiona Enter para cerrar..."