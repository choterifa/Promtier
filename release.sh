#!/bin/bash

# ==============================================================================
# Promtier (Free Release Build)
# ==============================================================================
# Genera un archivo ZIP firmado localmente (Ad-hoc) para uso independiente.
# ==============================================================================

set -e

APP_NAME="Promtier"
SCHEME="Promtier"
BUILD_PATH="./build"

# Colores para la terminal
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}==> Iniciando proceso de build para $APP_NAME...${NC}"

# 1. Limpieza
echo -e "${BLUE}==> Limpiando compilaciones anteriores...${NC}"
rm -rf "$BUILD_PATH"
mkdir -p "$BUILD_PATH"

# 2. Compilar App (Release mode)
echo -e "${BLUE}==> Compilando la aplicación funcional...${NC}"
xcodebuild -scheme "$SCHEME" \
    -configuration Release \
    -derivedDataPath "$BUILD_PATH/DerivedData" \
    -quiet \
    build

# 3. Localizar la App generada
BUILT_APP_PATH="$BUILD_PATH/DerivedData/Build/Products/Release/$APP_NAME.app"

# 4. Firma Ad-hoc (con tu identidad actual de Mac)
echo -e "${BLUE}==> Firmando la app localmente (Ad-hoc)...${NC}"
codesign --force --deep --sign - "$BUILT_APP_PATH"

# 5. Comprimir para distribuir
echo -e "${BLUE}==> Creando archivo ZIP para tus usuarios...${NC}"
FINAL_ZIP="$BUILD_PATH/${APP_NAME}_Indie.zip"
ditto -c -k --keepParent "$BUILT_APP_PATH" "$FINAL_ZIP"

echo -e "${GREEN}==> ¡LISTO! Tu aplicación compilada está en: $FINAL_ZIP${NC}"
echo -e "${BLUE}----------------------------------------------------------------${NC}"
echo -e "Instrucciones para tus usuarios:"
echo -e "1. Descomprimir el ZIP."
echo -e "2. Arrastrar a Aplicaciones."
echo -e "3. DAR CLICK DERECHO sobre la app y pulsar 'Abrir'."
echo -e "4. Pulsar 'Abrir de todos modos'."
echo -e "${BLUE}----------------------------------------------------------------${NC}"
