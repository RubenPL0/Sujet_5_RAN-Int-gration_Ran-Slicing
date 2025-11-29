#!/bin/bash
# Patch pour activer le mode slice-aware dans le scheduler OAI
# Ce script modifie les paramètres de configuration pour allocation PRB par slice

set -e

NAMESPACE="nexslice"
KUBECTL="sudo k3s kubectl"

echo "[INFO] Patching OAI scheduler for slice-aware PRB allocation..."

# Obtenir le pod gNB (CU-UP ou gNB monolithique)
GNB_POD=$($KUBECTL get pods -n $NAMESPACE -l app=oai-cu-up -o jsonpath='{.items[0].metadata.name}')

if [ -z "$GNB_POD" ]; then
    echo "[ERROR] gNB pod not found"
    exit 1
fi

echo "[INFO] Found gNB pod: $GNB_POD"

# Copier le fichier de politique dans le pod
$KUBECTL cp ran-slicing/configs/rrmPolicy.json $NAMESPACE/$GNB_POD:/tmp/rrmPolicy.json

echo "[SUCCESS] RAN slicing policy uploaded to gNB"
echo "[INFO] Restart gNB pod to apply changes"
