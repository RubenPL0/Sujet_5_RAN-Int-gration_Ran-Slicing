#!/bin/bash
# =============================================================================
# NexSlice - Script de Nettoyage Tests iperf3
# =============================================================================

NAMESPACE="nexslice"
KUBECTL="sudo k3s kubectl"

# Couleurs
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo ""
echo "╔══════════════════════════════════════════════════════════════════╗"
echo "║            NexSlice - Nettoyage Tests iperf3                     ║"
echo "╚══════════════════════════════════════════════════════════════════╝"
echo ""

echo -e "${YELLOW}[INFO]${NC} Suppression du serveur iperf3..."
$KUBECTL delete pod iperf3-server -n $NAMESPACE 2>/dev/null && echo "✓ Pod supprimé" || echo "  Pod déjà supprimé"
$KUBECTL delete svc iperf3-svc -n $NAMESPACE 2>/dev/null && echo "✓ Service supprimé" || echo "  Service déjà supprimé"

echo ""
echo -e "${YELLOW}[INFO]${NC} Suppression des limitations QoS..."

# UPF1
UPF1=$($KUBECTL get pods -n $NAMESPACE -l app.kubernetes.io/name=oai-upf -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
if [ -n "$UPF1" ]; then
    $KUBECTL exec -n $NAMESPACE $UPF1 -- tc qdisc del dev eth0 root 2>/dev/null && echo "✓ UPF1: QoS supprimée" || echo "  UPF1: Pas de QoS"
fi

# UPF2
UPF2=$($KUBECTL get pods -n $NAMESPACE -l app.kubernetes.io/name=oai-upf2 -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
if [ -n "$UPF2" ]; then
    $KUBECTL exec -n $NAMESPACE $UPF2 -- tc qdisc del dev eth0 root 2>/dev/null && echo "✓ UPF2: QoS supprimée" || echo "  UPF2: Pas de QoS"
fi

# UPF3
UPF3=$($KUBECTL get pods -n $NAMESPACE -l app.kubernetes.io/name=oai-upf3 -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
if [ -n "$UPF3" ]; then
    $KUBECTL exec -n $NAMESPACE $UPF3 -- tc qdisc del dev eth0 root 2>/dev/null && echo "✓ UPF3: QoS supprimée" || echo "  UPF3: Pas de QoS"
fi

echo ""
echo -e "${GREEN}✓ Nettoyage terminé !${NC}"
echo ""
