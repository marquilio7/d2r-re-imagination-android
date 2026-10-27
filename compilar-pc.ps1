# compilar-pc.ps1
# Compila el port para PC (Windows) usando MSYS2/ucrt64.
# Requisitos: MSYS2 instalado en C:\msys64 (con ucrt64).
param(
    [string]$Msys2 = "C:\msys64",
    [switch]$InstalarSDL2
)

$ErrorActionPreference = "Stop"
$bash = Join-Path $Msys2 "usr\bin\bash.exe"
if (-not (Test-Path $bash)) { throw "No encontre MSYS2 en $Msys2. Instala MSYS2 o pasa -Msys2." }

# pasar el script a la ruta POSIX de MSYS2
$root = $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($root)) { $root = (Get-Location).Path }
$drive = $root.Substring(0,1).ToLower()
$rest = $root.Substring(2) -replace '\\','/'
$rootPosix = "/$drive$rest"
$scriptPosix = "$rootPosix/compilar-pc.sh"

Write-Host "Compilando en MSYS2 UCRT64..." -ForegroundColor Cyan
$cmd = "export PATH=/ucrt64/bin:/usr/bin:`$PATH; cd '$rootPosix' && bash compilar-pc.sh"
& $bash -c $cmd
$ec = $LASTEXITCODE
if ($ec -ne 0) { throw "La compilacion fallo (exit $ec)." }

$exe = Join-Path $root "build-pc\d2port.exe"
if (Test-Path $exe) {
    Write-Host ""
    Write-Host "Listo: $exe" -ForegroundColor Green
    Write-Host "Para jugar: copia d2port.exe + SDL2.dll a una carpeta con data/ y save/."
} else {
    Write-Host "No encontre el .exe esperado. Revisa la salida." -ForegroundColor Yellow
}