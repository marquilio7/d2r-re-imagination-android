#!/usr/bin/env bash
# compilar-pc.sh  (correr desde MSYS2 UCRT64, o via compilar-pc.ps1)
# Compila el port para PC (Windows) con MSYS2/ucrt64.
#
# Hay dos carpetas "data" distintas:
#   1. Data original de D2R: la instalacion del juego (ej: D:/J/Diablo II Resurrected)
#   2. Data preparada del port: los archivos extraidos (ej: D:/J/d2port/data)
# Este script compila y deja el binario en dist/windows/.
set -euo pipefail

export PATH="/ucrt64/bin:/usr/bin:$PATH"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
if [[ -f "$SCRIPT_DIR/CMakeLists.txt" ]]; then
    ROOT="$SCRIPT_DIR"
else
    ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
fi

BUILD="$ROOT/build-pc"
OUT_DIR="$ROOT/dist/windows"
SDL2_DIR="/ucrt64/lib/cmake/SDL2"

# 1. SDL2 dev libs (si faltan)
if [[ ! -f /ucrt64/include/SDL2/SDL.h ]]; then
    echo "Instalando SDL2 (ucrt64) con pacman..."
    pacman -S --needed --noconfirm mingw-w64-ucrt-x86_64-SDL2
fi
if [[ ! -d "$SDL2_DIR" ]]; then
    echo "No encontre el cmake de SDL2 en $SDL2_DIR" >&2
    echo "Instala con: pacman -S mingw-w64-ucrt-x86_64-SDL2" >&2
    exit 1
fi

# 2. Configurar y compilar
echo "Configurando CMake..."
cmake -S "$ROOT" -B "$BUILD" -DCMAKE_BUILD_TYPE=Release \
      -DSDL2_DIR="$SDL2_DIR" 2>&1 | tail -3

echo "Compilando d2port..."
cmake --build "$BUILD" --target d2port -j"$(nproc)" 2>&1 | tail -5

mkdir -p "$OUT_DIR"
cp -f "$BUILD/d2port.exe" "$OUT_DIR/d2port.exe"
cp -f /ucrt64/bin/SDL2.dll "$OUT_DIR/SDL2.dll" 2>/dev/null || true

echo ""
echo "Listo. Binario en: $OUT_DIR/d2port.exe"
echo "Compilacion terminada."