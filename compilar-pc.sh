#!/usr/bin/env bash
# compilar-pc.sh  (correr desde MSYS2 UCRT64, o via compilar-pc.ps1)
# Compila el port para PC (Windows) con MSYS2/ucrt64.
set -euo pipefail

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

# 2. Configurar y compilar
echo "Configurando CMake..."
cmake -S "$ROOT" -B "$BUILD" -DCMAKE_BUILD_TYPE=Release \
      -DSDL2_DIR="$SDL2_DIR" 2>&1 | tail -3

echo "Compilando d2port..."
cmake --build "$BUILD" --target d2port -j"$(nproc)" 2>&1 | tail -5

echo ""
echo "Listo. Binario en: $BUILD/d2port.exe"

# 3. Detectar carpeta data/ automaticamente
detect_data() {
    local candidates=()
    for p in "$ROOT/data" "$SCRIPT_DIR/data" "D:/J/d2port/data"; do
        if [[ -f "$p/global/palette/act1" ]]; then candidates+=("$p"); fi
    done
    # busqueda limitada (2 niveles)
    if [[ ${#candidates[@]} -eq 0 ]]; then
        while IFS= read -r d; do
            if [[ -f "$d/global/palette/act1" ]]; then candidates+=("$d"); fi
        done < <(find "$(dirname "$ROOT")" -maxdepth 3 -type d -name data 2>/dev/null)
    fi
    if [[ ${#candidates[@]} -gt 0 ]]; then
        echo ""
        echo "Carpetas data/ detectadas:"
        local i=1
        for c in "${candidates[@]}"; do echo "  [$i] $c"; i=$((i+1)); done
        echo "  [0] Ingresar ruta manualmente"
        read -rp "Elegi una opcion: " sel
        if [[ "$sel" =~ ^[0-9]+$ ]] && (( sel >= 1 && sel <= ${#candidates[@]} )); then
            DATA_PATH="${candidates[$((sel-1))]}"
        elif [[ "$sel" == "0" || -z "$sel" ]]; then
            read -rp "Ruta de la carpeta data/: " DATA_PATH
        else
            DATA_PATH="$sel"
        fi
    else
        echo ""
        echo "No detecte ninguna carpeta data/ valida."
        read -rp "Ruta de la carpeta data/ (o Enter para saltear): " DATA_PATH
    fi
}

DATA_PATH=""
if [[ -t 0 ]]; then
    detect_data
fi

# 4. Copiar exe al lado de data/ para poder jugar
if [[ -n "$DATA_PATH" && -f "$DATA_PATH/global/palette/act1" ]]; then
    PLAY_DIR="$(dirname "$DATA_PATH")"
    echo ""
    echo "Se va a copiar d2port.exe + SDL2.dll a: $PLAY_DIR"
    read -rp "Confirmar? [S/n]: " resp
    if [[ -z "$resp" || "$resp" =~ ^[sSyY]$ ]]; then
        [[ -f "$PLAY_DIR/d2port.exe" ]] && cp -f "$PLAY_DIR/d2port.exe" "$PLAY_DIR/d2port.exe.bak"
        cp -f "$BUILD/d2port.exe" "$PLAY_DIR/d2port.exe"
        cp -f /ucrt64/bin/SDL2.dll "$PLAY_DIR/SDL2.dll" 2>/dev/null || true
        echo "Listo. Ejecuta d2port.exe en $PLAY_DIR para jugar."
    else
        echo "Salteado. El binario quedo en $BUILD/d2port.exe"
    fi
else
    echo "Binario disponible en: $BUILD/d2port.exe"
fi

# copiar a dist/windows/ (y tambien a la carpeta del script para compartir)
OUT_DIR="$ROOT/dist/windows"
mkdir -p "$OUT_DIR"
cp -f "$BUILD/d2port.exe" "$OUT_DIR/d2port.exe" 2>/dev/null || true
cp -f /ucrt64/bin/SDL2.dll "$OUT_DIR/SDL2.dll" 2>/dev/null || true
cp -f "$BUILD/d2port.exe" "$SCRIPT_DIR/d2port.exe" 2>/dev/null || true
cp -f /ucrt64/bin/SDL2.dll "$SCRIPT_DIR/SDL2.dll" 2>/dev/null || true

echo ""
echo "Compilacion terminada."