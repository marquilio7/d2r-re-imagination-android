#!/usr/bin/env bash
# instalar-android.sh
# Instala el APK del port de Diablo II en un celular Android por adb y copia
# la carpeta data/ (archivos del juego) al almacenamiento interno de la app.
#
# Uso:
#   ./instalar-android.sh [-a ruta/al/app.apk] [-d ruta/a/data] [-l] [-u]
#
# Requisitos: adb en el PATH, telefono conectado con depuracion USB activada.

set -euo pipefail
PKG="org.libsdl.app"
ACTIVITY="$PKG/.SDLActivity"
REMOTE_TMP="/data/local/tmp/d2port-data"

APK=""
DATA=""
LAUNCH=0
UNINSTALL=0

while [[ $# -gt 0 ]]; do
    case "$1" in
        -a|--apk) APK="$2"; shift 2 ;;
        -d|--data) DATA="$2"; shift 2 ;;
        -l|--launch) LAUNCH=1; shift ;;
        -u|--uninstall) UNINSTALL=1; shift ;;
        *) echo "Opcion desconocida: $1"; exit 1 ;;
    esac
done

if ! command -v adb >/dev/null 2>&1; then
    echo "ERROR: adb no esta en el PATH." >&2; exit 1
fi

if [[ $UNINSTALL -eq 1 ]]; then
    adb uninstall "$PKG" || true
    adb shell rm -rf "$REMOTE_TMP" 2>/dev/null || true
    echo "Desinstalado."
    exit 0
fi

# dispositivo
if ! adb devices | grep -q $'\tdevice$'; then
    echo "No hay telefono conectado. Conecta el USB, activa depuracion USB y autoriza la clave RSA." >&2
    adb devices
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# raiz del repo (donde esta CMakeLists.txt): ahi se busca data/ por defecto
if [[ -f "$SCRIPT_DIR/CMakeLists.txt" ]]; then
    ROOT="$SCRIPT_DIR"
elif [[ -f "$SCRIPT_DIR/../CMakeLists.txt" ]]; then
    ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
else
    ROOT="$SCRIPT_DIR"
fi
DIST="$ROOT/dist"

# resolver APK (preferir el debug: es debuggeable y permite copiar data/)
if [[ -z "$APK" ]]; then
    for c in "$DIST/app-debug.apk" "$SCRIPT_DIR/app-debug.apk" \
             "$DIST/app-release.apk" "$SCRIPT_DIR/app-release.apk" \
             "$SCRIPT_DIR/debug/app-debug.apk" "$SCRIPT_DIR/release/app-release.apk"; do
        if [[ -f "$c" ]]; then APK="$c"; break; fi
    done
    if [[ -z "$APK" ]]; then
        APK=$(find "$ROOT" -name 'app-*debug*.apk' -print -quit 2>/dev/null || true)
        [[ -z "$APK" ]] && APK=$(find "$ROOT" -name 'app-*.apk' -print -quit 2>/dev/null || true)
    fi
fi
[[ -f "$APK" ]] || { echo "ERROR: APK no encontrado. Usa -a ruta/al/app.apk" >&2; exit 1; }
echo "APK: $APK"

# resolver data (por defecto: data/ en la raiz del repo)
if [[ -z "$DATA" ]]; then
    if [[ -f "$ROOT/data/global/palette/act1" ]]; then
        DATA="$ROOT/data"
    else
        DATA=$(find "$ROOT" -type d -name data -print -quit 2>/dev/null || true)
    fi
fi
[[ -d "$DATA" ]] || { echo "ERROR: carpeta data no encontrada. Usa -d ruta/a/data" >&2; exit 1; }
if [[ ! -f "$DATA/global/palette/act1" ]]; then
    echo "Aviso: no veo data/global/palette/act1. La copia puede estar incompleta." >&2
fi
echo "Data: $DATA"

echo "Instalando APK..."
adb install -r "$APK"

echo "Preparando carpetas internas..."
adb shell run-as "$PKG" rm -rf files/data files/save 2>/dev/null || true
adb shell run-as "$PKG" mkdir -p files/data files/save

echo "Copiando data/ al telefono (2 GB aprox., puede tardar)..."
adb shell rm -rf "$REMOTE_TMP" 2>/dev/null || true
adb push "$DATA" "$REMOTE_TMP"

adb shell run-as "$PKG" rm -rf files/data
adb shell run-as "$PKG" mkdir -p files/data
if adb shell test -d "$REMOTE_TMP/data" 2>/dev/null; then SRC="$REMOTE_TMP/data/."; else SRC="$REMOTE_TMP/."; fi
adb shell run-as "$PKG" cp -r "$SRC" files/data/

COUNT=$(adb shell run-as "$PKG" find files/data -type f | wc -l)
echo "Archivos copiados: $COUNT"
if [[ "$COUNT" -lt 30000 ]]; then
    echo "Aviso: se esperaban ~33899 archivos. Revisa la copia." >&2
fi

adb shell rm -rf "$REMOTE_TMP" 2>/dev/null || true

if [[ $LAUNCH -eq 1 ]]; then
    echo "Lanzando el juego..."
    adb shell am start -n "$ACTIVITY" >/dev/null 2>&1 || true
fi

echo ""
echo "Listo. El juego esta instalado. Abrelo desde el launcher del telefono."