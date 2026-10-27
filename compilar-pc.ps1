# compilar-pc.ps1
# Compila el port para PC (Windows) usando MSYS2/ucrt64.
# Despues de compilar, detecta la carpeta data/ y copia el exe + SDL2.dll
# al lado para que se pueda jugar directamente.
param(
    [string]$Msys2 = "C:\msys64",
    [string]$Data = "",
    [switch]$NoCopiar
)

$ErrorActionPreference = "Stop"
$bash = Join-Path $Msys2 "usr\bin\bash.exe"
if (-not (Test-Path $bash)) { throw "No encontre MSYS2 en $Msys2. Instala MSYS2 o pasa -Msys2." }

# detectar la raiz del codigo fuente (donde esta CMakeLists.txt)
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
# copiar a dist/windows/ (y tambien a la carpeta del script para compartir)
Copy-Item $exe (Join-Path $outDir "d2port.exe") -Force
if (Test-Path $sdl) { Copy-Item $sdl (Join-Path $outDir "SDL2.dll") -Force }
Copy-Item $exe (Join-Path $root "d2port.exe") -Force
if (Test-Path $sdl) { Copy-Item $sdl (Join-Path $root "SDL2.dll") -Force }

# --- detectar carpeta data/ ---
if ([string]::IsNullOrWhiteSpace($Data)) {
    $candidates = @()
    # lugares comunes
    foreach ($p in @(
        (Join-Path $root "data"),
        "D:\J\d2port\data",
        "C:\J\Diablo II\data",
        (Join-Path (Split-Path $root -Parent) "d2port\data")
    )) {
        if (Test-Path (Join-Path $p "global\palette\act1")) { $candidates += $p }
    }
    # busqueda recursiva limitada (2 niveles) por si esta en otro lado
    if ($candidates.Count -eq 0) {
        $found = Get-ChildItem -Path (Split-Path $root -Parent) -Recurse -Directory -Filter "data" -Depth 3 -ErrorAction SilentlyContinue |
            Where-Object { Test-Path (Join-Path $_.FullName "global\palette\act1") } | Select-Object -First 5
        foreach ($f in $found) { $candidates += $f.FullName }
    }

    if ($candidates.Count -gt 0) {
        Write-Host ""
        Write-Host "Carpetas data/ detectadas:" -ForegroundColor Cyan
        for ($i = 0; $i -lt $candidates.Count; $i++) {
            Write-Host "  [$($i+1)] $($candidates[$i])"
        }
        Write-Host "  [0] Ingresar ruta manualmente"
        $sel = "1"
        try { $s = Read-Host "Elegi una opcion"; if ($s) { $sel = $s } } catch { }
        if ($sel -match '^\d+$' -and [int]$sel -ge 1 -and [int]$sel -le $candidates.Count) {
            $Data = $candidates[[int]$sel - 1]
        } elseif ($sel -eq "0" -or [string]::IsNullOrWhiteSpace($sel)) {
            $Data = "D:\J\d2port\data"
            try { $d = Read-Host "Ruta de la carpeta data/"; if ($d) { $Data = $d } } catch { }
        } else {
            $Data = $sel
        }
    } else {
        Write-Host ""
        Write-Host "No detecte ninguna carpeta data/ valida." -ForegroundColor Yellow
        $Data = "D:\J\d2port\data"
        try { $d = Read-Host "Ruta de la carpeta data/ (o Enter para saltear)"; if ($d) { $Data = $d } } catch { }
    }
}

# --- copiar exe al lado de data/ para poder jugar ---
if (-not [string]::IsNullOrWhiteSpace($Data) -and -not $NoCopiar) {
    if (-not (Test-Path (Join-Path $Data "global\palette\act1"))) {
        Write-Host "Aviso: '$Data' no parece una carpeta data/ valida. Salteo la copia." -ForegroundColor Yellow
    } else {
        $playDir = Split-Path $Data -Parent
        Write-Host ""
        Write-Host "Se va a copiar d2port.exe + SDL2.dll a: $playDir" -ForegroundColor Cyan
        $resp = "S"
        try { $r = Read-Host "Confirmar? [S/n]"; if ($r) { $resp = $r } } catch { }
        if ($resp -eq "" -or $resp -match '^[sSyY]') {
            # backup del exe existente
            $existingExe = Join-Path $playDir "d2port.exe"
            if (Test-Path $existingExe) {
                Copy-Item $existingExe "$existingExe.bak" -Force
            }
            Copy-Item $exe (Join-Path $playDir "d2port.exe") -Force
            if (Test-Path $sdl) { Copy-Item $sdl (Join-Path $playDir "SDL2.dll") -Force }
            Write-Host "Listo. Ejecuta d2port.exe en $playDir para jugar." -ForegroundColor Green
        } else {
            Write-Host "Salteado. El binario quedo en $root\d2port.exe"
        }
    }
} else {
    Write-Host "Binario disponible en: $outDir\d2port.exe" -ForegroundColor Green
}

Write-Host ""
Write-Host "Compilacion terminada." -ForegroundColor Green