# compilar-pc.ps1
# Compila el port para PC (Windows) usando MSYS2/ucrt64.
# Opcionalmente copia el exe + SDL2.dll al lado de la carpeta data/ preparada.
#
# Uso:
#   .\compilar-pc.ps1 [-Data ruta\a\data] [-NoCopiar] [-Msys2 C:\msys64]
#
# Hay dos carpetas "data" distintas:
#   1. Data original de D2R: la instalacion del juego (ej: D:\J\Diablo II Resurrected)
#   2. Data preparada del port: los archivos extraidos para el port (ej: D:\J\d2port\data)
# Este script usa la #2 (la preparada) para copiar el exe al lado y poder jugar.
# Si no la encuentra, te avisa y te dice como generarla desde la #1 con el importador.

param(
    [string]$Msys2 = "C:\msys64",
    [string]$Data = "",
    [switch]$NoCopiar
)

$ErrorActionPreference = "Stop"
$bash = Join-Path $Msys2 "usr\bin\bash.exe"
if (-not (Test-Path $bash)) { throw "No encontre MSYS2 en $Msys2. Instala MSYS2 o pasa -Msys2." }

# detectar raiz del codigo fuente
$root = $PSScriptRoot
if (-not (Test-Path (Join-Path $root "CMakeLists.txt"))) {
    $parent = Split-Path $root -Parent
    if (Test-Path (Join-Path $parent "CMakeLists.txt")) { $root = $parent }
}
if ([string]::IsNullOrWhiteSpace($root)) { $root = (Get-Location).Path }
$drive = $root.Substring(0,1).ToLower()
$rest = $root.Substring(2) -replace '\\','/'
$rootPosix = "/$drive$rest"
$outDir = Join-Path $root "dist\windows"
New-Item -ItemType Directory -Force -Path $outDir | Out-Null

# --- compilar ---
Write-Host "Compilando en MSYS2 UCRT64..." -ForegroundColor Cyan
$cmd = "export PATH=/ucrt64/bin:/usr/bin:`$PATH; cd '$rootPosix' && bash compilar-pc.sh"
& $bash -c $cmd
if ($LASTEXITCODE -ne 0) { throw "La compilacion fallo (exit $LASTEXITCODE)." }

$exe = Join-Path $root "build-pc\d2port.exe"
$sdl = "C:\msys64\ucrt64\bin\SDL2.dll"
if (-not (Test-Path $exe)) { throw "No encontre el .exe esperado en $exe" }

# copiar a dist/windows/ (para compartir) y a la raiz del repo
Copy-Item $exe (Join-Path $outDir "d2port.exe") -Force
if (Test-Path $sdl) { Copy-Item $sdl (Join-Path $outDir "SDL2.dll") -Force }
Copy-Item $exe (Join-Path $root "d2port.exe") -Force
if (Test-Path $sdl) { Copy-Item $sdl (Join-Path $root "SDL2.dll") -Force }

# --- detectar instalacion de D2R (data original) ---
function Find-D2RPath {
    $roots = @("HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall","HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall")
    foreach ($r in $roots) {
        if (-not (Test-Path $r)) { continue }
        foreach ($k in (Get-ChildItem $r -ErrorAction SilentlyContinue)) {
            $p = Get-ItemProperty $k.PSPath -ErrorAction SilentlyContinue
            if ($p.DisplayName -match 'Diablo II Resurrected' -and $p.InstallLocation -and (Test-Path $p.InstallLocation)) {
                return $p.InstallLocation
            }
        }
    }
    foreach ($p in @("D:\J\Diablo II Resurrected","C:\Program Files (x86)\Diablo II Resurrected","C:\Program Files\Diablo II Resurrected")) {
        if (Test-Path (Join-Path $p ".build.info")) { return $p }
    }
    return $null
}
$d2rPath = Find-D2RPath
if ($d2rPath) { Write-Host "Data original de D2R detectada en: $d2rPath" -ForegroundColor Green }

# --- detectar data preparada del port ---
# Busca carpetas que tengan la estructura del port: data/global/palette/act1
if ([string]::IsNullOrWhiteSpace($Data)) {
    $candidates = @()
    foreach ($p in @((Join-Path $root "data"), "D:\J\d2port\data", (Join-Path (Split-Path $root -Parent) "d2port\data"))) {
        if (Test-Path (Join-Path $p "global\palette\act1")) { $candidates += $p }
    }
    # busqueda recursiva limitada
    if ($candidates.Count -eq 0) {
        $found = Get-ChildItem -Path (Split-Path $root -Parent) -Recurse -Directory -Filter "data" -Depth 3 -ErrorAction SilentlyContinue |
            Where-Object { Test-Path (Join-Path $_.FullName "global\palette\act1") } | Select-Object -First 5
        foreach ($f in $found) { $candidates += $f.FullName }
    }
    if ($candidates.Count -gt 0) {
        $Data = $candidates[0]
        if ($candidates.Count -gt 1) {
            Write-Host "Carpetas data/ preparadas encontradas:" -ForegroundColor Cyan
            for ($i = 0; $i -lt $candidates.Count; $i++) { Write-Host "  [$($i+1)] $($candidates[$i])" }
            Write-Host "  Usando la primera. Pasa -Data para elegir otra."
        }
    }
}

# --- copiar exe al lado de la data preparada para poder jugar ---
if (-not $NoCopiar) {
    if ([string]::IsNullOrWhiteSpace($Data) -or -not (Test-Path (Join-Path $Data "global\palette\act1"))) {
        Write-Host ""
        Write-Host "No se encontro data/ preparada del port." -ForegroundColor Yellow
        if ($d2rPath) {
            Write-Host "Tenes la data original de D2R en: $d2rPath" -ForegroundColor Cyan
            Write-Host "Para generar la data preparada, ejecuta el importador:" -ForegroundColor Cyan
            Write-Host "  d2port-importar.exe --idioma esMX --juego `"$d2rPath`"" -ForegroundColor Gray
            Write-Host "  (genera la carpeta data/ que el port necesita)" -ForegroundColor Gray
        }
        Write-Host "Binario disponible en: $outDir\d2port.exe" -ForegroundColor Green
    } else {
        $playDir = Split-Path $Data -Parent
        $existingExe = Join-Path $playDir "d2port.exe"
        if (Test-Path $existingExe) { Copy-Item $existingExe "$existingExe.bak" -Force }
        Copy-Item $exe $existingExe -Force
        if (Test-Path $sdl) { Copy-Item $sdl (Join-Path $playDir "SDL2.dll") -Force }
        Write-Host ""
        Write-Host "Exe copiado a: $playDir\d2port.exe" -ForegroundColor Green
        Write-Host "Ejecuta d2port.exe en $playDir para jugar." -ForegroundColor Green
    }
} else {
    Write-Host "Binario disponible en: $outDir\d2port.exe" -ForegroundColor Green
}

Write-Host ""
Write-Host "Compilacion terminada." -ForegroundColor Green
Write-Host ""
Read-Host "Presiona Enter para cerrar..."
