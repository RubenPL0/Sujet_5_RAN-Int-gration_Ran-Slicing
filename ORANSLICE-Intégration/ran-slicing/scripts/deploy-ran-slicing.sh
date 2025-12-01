#!/bin/bash
# Script de déploiement RAN Slicing pour NexSlice

set -e

NAMESPACE="nexslice"
KUBECTL="sudo k3s kubectl"

echo "╔══════════════════════════════════════════════════════════════════╗"
echo "║         Déploiement RAN Slicing - NexSlice                      ║"
echo "╚══════════════════════════════════════════════════════════════════╝"
echo ""

# Vérifier que le namespace existe
if ! $KUBECTL get namespace $NAMESPACE &>/dev/null; then
    echo "[INFO] Création du namespace $NAMESPACE..."
    $KUBECTL create namespace $NAMESPACE
fi

# Déployer le Helm chart
echo "[INFO] Déploiement du chart oai-gnb-slicing..."
cd 5g_ran/oai-gnb-slicing

helm upgrade --install oai-gnb-slicing . \
    --namespace $NAMESPACE \
    --create-namespace \
    --wait \
    --timeout 5m

echo ""
echo "[SUCCESS] Déploiement terminé!"
echo ""
echo "Vérification des pods:"
$KUBECTL get pods -n $NAMESPACE -l app=oai-gnb-slicing

echo ""
echo "Pour voir les logs du scheduler slice-aware:"
echo "  kubectl logs -n $NAMESPACE -l app=oai-gnb-slicing -f | grep RAN_SLICING"
echo ""
