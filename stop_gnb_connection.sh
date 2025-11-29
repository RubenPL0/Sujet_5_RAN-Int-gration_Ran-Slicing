#!/bin/bash
# =============================================================================
# Script de Nettoyage : Arrêter gNB, UE, Port-Forward
# =============================================================================

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo ""
echo "╔══════════════════════════════════════════════════════════════════╗"
echo "║              Nettoyage Connexion gNB ↔ Core                     ║"
echo "╚══════════════════════════════════════════════════════════════════╝"
echo ""

# Arrêter gNB
echo -e "${YELLOW}[INFO]${NC} Arrêt du gNB..."
sudo pkill -9 nr-softmodem 2>/dev/null && echo -e "${GREEN}✓${NC} gNB arrêté" || echo "  gNB déjà arrêté"

# Arrêter UE
echo -e "${YELLOW}[INFO]${NC} Arrêt du UE..."
sudo pkill -9 nr-uesoftmodem 2>/dev/null && echo -e "${GREEN}✓${NC} UE arrêté" || echo "  UE déjà arrêté"

# Arrêter port-forward
echo -e "${YELLOW}[INFO]${NC} Arrêt du port-forward AMF..."
if [ -f /tmp/amf-portforward.pid ]; then
    PID=$(cat /tmp/amf-portforward.pid)
    kill $PID 2>/dev/null && echo -e "${GREEN}✓${NC} Port-forward arrêté (PID: $PID)" || echo "  Déjà arrêté"
    rm /tmp/amf-portforward.pid
else
    pkill -f "port-forward.*38412" 2>/dev/null && echo -e "${GREEN}✓${NC} Port-forward arrêté" || echo "  Déjà arrêté"
fi

# Supprimer interface oaitun_ue1
echo -e "${YELLOW}[INFO]${NC} Suppression de l'interface oaitun_ue1..."
sudo ip link del oaitun_ue1 2>/dev/null && echo -e "${GREEN}✓${NC} Interface supprimée" || echo "  Interface non présente"

# Nettoyer les fichiers temporaires
echo -e "${YELLOW}[INFO]${NC} Nettoyage fichiers temporaires..."
rm -f /tmp/add_ue.sql
rm -f /tmp/amf-portforward.log

echo ""
echo -e "${GREEN}✓ Nettoyage terminé !${NC}"
echo ""
