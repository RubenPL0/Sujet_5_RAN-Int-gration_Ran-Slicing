#!/bin/bash
# Script de nettoyage

NAMESPACE="nexslice"
KUBECTL="sudo k3s kubectl"

echo "Nettoyage des tests iperf3..."

# Supprimer serveur iperf3
kubectl delete pod iperf3-server -n $NAMESPACE 2>/dev/null || true
kubectl delete svc iperf3-svc -n $NAMESPACE 2>/dev/null || true

# Supprimer limitations QoS
UPF1=$($KUBECTL get pods -n $NAMESPACE -l app.kubernetes.io/name=oai-upf -o jsonpath='{.items[0].metadata.name}')
UPF2=$($KUBECTL get pods -n $NAMESPACE -l app.kubernetes.io/name=oai-upf2 -o jsonpath='{.items[0].metadata.name}')
UPF3=$($KUBECTL get pods -n $NAMESPACE -l app.kubernetes.io/name=oai-upf3 -o jsonpath='{.items[0].metadata.name}')

$KUBECTL exec -n $NAMESPACE $UPF1 -- tc qdisc del dev eth0 root 2>/dev/null || true
$KUBECTL exec -n $NAMESPACE $UPF2 -- tc qdisc del dev eth0 root 2>/dev/null || true
$KUBECTL exec -n $NAMESPACE $UPF3 -- tc qdisc del dev eth0 root 2>/dev/null || true

echo "✓ Nettoyage terminé"
