#!/usr/bin/env bash
# compilar-pc.sh  (correr desde MSYS2 UCRT64, o via compilar-pc.ps1)
# Compila el port para PC (Windows) con MSYS2/ucrt64.
set -euo pipefail

# MSYS2 UCRT64: asegurar que cmake/gcc esten en PATH
export PATH="/ucrt64/bin:/usr/bin:$PATH"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
if [[ -f "$SCRIPT_DIR/CMakeLists.txt" ]]; then
    ROOT="$SCRIPT_DIR"
else
    ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
fi
BUILD="$ROOT/build-pc"
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

# 2. CascLib (solo para el importador; el juego no lo necesita)
if [[ ! -f /ucrt64/lib/libCascLib.a && ! -f /ucrt64/lib/libcasc.a ]]; then
    echo "Aviso: CascLib no esta instalado. El importador (d2port-importar) no se va a poder compilar."
    echo "       Para el importador: pacman -S mingw-w64-ucrt-x86_64-casclib  (si existe) o compilarlo a mano."
fi

# 3. Configurar y compilar
echo "Configurando CMake..."
cmake -S "$ROOT" -B "$BUILD" -DCMAKE_BUILD_TYPE=Release \
      -DSDL2_DIR="$SDL2_DIR" 2>&1 | tail -5

echo "Compilando d2port..."
cmake --build "$BUILD" --target d2port -j"$(nproc)" 2>&1 | tail -20

echo ""
echo "Listo. Binario en: $BUILD/d2port.exe"
# copiar a la carpeta del script para compartir
cp -f "$BUILD/d2port.exe" "$(dirname "$0")/d2port.exe" 2>/dev/null || true
cp -f /ucrt64/bin/SDL2.dll "$(dirname "$0")/SDL2.dll" 2>/dev/null || true
echo "Copiado a: $(dirname "$0")/d2port.exe"
echo "Para jugar, copia d2port.exe + SDL2.dll a una carpeta con data/ y save/."