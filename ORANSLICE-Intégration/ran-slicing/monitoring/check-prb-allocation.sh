#!/bin/bash
# Monitoring allocation PRB par slice

NAMESPACE="nexslice"
KUBECTL="sudo k3s kubectl"

GNB_POD=$($KUBECTL get pods -n $NAMESPACE -l app=oai-gnb-slicing -o jsonpath='{.items[0].metadata.name}')

if [ -z "$GNB_POD" ]; then
    echo "[ERROR] gNB pod not found"
    exit 1
fi

echo "=== Allocation PRB par Slice ==="
echo ""

$KUBECTL exec -n $NAMESPACE $GNB_POD -- cat /proc/net/ran_slicing/stats 2>/dev/null || \
$KUBECTL logs -n $NAMESPACE $GNB_POD --tail=50 | grep -i "PRB\|slice" || \
echo "[INFO] Statistiques non disponibles. Vérifier les logs manuellement."

echo ""
echo "Logs récents du scheduler:"
$KUBECTL logs -n $NAMESPACE $GNB_POD --tail=20 | grep -i "sched\|alloc"
