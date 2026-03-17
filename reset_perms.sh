#!/bin/bash
# Script para resetear los permisos de accesibilidad de Promtier durante el desarrollo
BUNDLE_ID="com.valencia.Promtier.app"

echo "🧹 Reseteando permisos de TCC para $BUNDLE_ID..."
tccutil reset Accessibility $BUNDLE_ID
echo "✅ Hecho. La próxima vez que abras la app, solicitará permisos de forma limpia."
