#!/bin/bash
# =============================================================================
# REPARATION TOTALE : IP Forwarding + NAT + QoS (Dynamique via JSON)
# =============================================================================

NAMESPACE="nexslice"
KUBECTL="sudo k3s kubectl"
JSON_FILE="5_rrmPolicy.json"

# --- 1. Définition des valeurs par défaut ---
RATE_EMBB="100"
RATE_URLLC="50"
RATE_MMTC="20"

echo "╔══════════════════════════════════════════════════════════════════╗"
echo "║           MAINTENANCE RÉSEAU 5G (ROUTING + QoS)                  ║"
echo "╚══════════════════════════════════════════════════════════════════╝"
echo ""

# --- 2. Lecture du fichier de politique (si présent) ---
if [ -f "$JSON_FILE" ]; then
    echo " Fichier de politique '$JSON_FILE' détecté."
    
    # Vérification si jq est installé
    if command -v jq &> /dev/null; then
        echo "   Lecture des configurations..."
        
        # Extraction des valeurs maxPRB pour définir le débit max (QoS)
        # On utilise maxPRB comme valeur en Mbits pour la simulation
        NEW_EMBB=$(jq -r '.slices[] | select(.label=="eMBB") | .maxPRB' $JSON_FILE)
        NEW_URLLC=$(jq -r '.slices[] | select(.label=="URLLC") | .maxPRB' $JSON_FILE)
        NEW_MMTC=$(jq -r '.slices[] | select(.label=="mMTC") | .maxPRB' $JSON_FILE)

        # Si les valeurs sont trouvées, on écrase les défauts
        if [ ! -z "$NEW_EMBB" ] && [ "$NEW_EMBB" != "null" ]; then RATE_EMBB=$NEW_EMBB; fi
        if [ ! -z "$NEW_URLLC" ] && [ "$NEW_URLLC" != "null" ]; then RATE_URLLC=$NEW_URLLC; fi
        if [ ! -z "$NEW_MMTC" ] && [ "$NEW_MMTC" != "null" ]; then RATE_MMTC=$NEW_MMTC; fi
        
        echo "    Configuration chargée depuis le JSON.(Utilisation des valeurs maxPRB comme Mbit/s)."
    else
        echo "    'jq' n'est pas installé. Utilisation des valeurs par défaut."
        echo "      (Installez-le avec : sudo apt-get install jq)"
    fi
else
    echo " Fichier '$JSON_FILE' introuvable. Utilisation des valeurs par défaut."
fi

# --- 3. Récupération des pods ---
UPF1=$($KUBECTL get pod -n $NAMESPACE -l app.kubernetes.io/name=oai-upf -o jsonpath='{.items[0].metadata.name}')
UPF2=$($KUBECTL get pod -n $NAMESPACE -l app.kubernetes.io/name=oai-upf2 -o jsonpath='{.items[0].metadata.name}')
UPF3=$($KUBECTL get pod -n $NAMESPACE -l app.kubernetes.io/name=oai-upf3 -o jsonpath='{.items[0].metadata.name}')

if [ -z "$UPF1" ]; then echo "Erreur: UPFs introuvables"; exit 1; fi

echo ""
echo "Configuration cible :"
echo "  • UPF1 (eMBB)  : Pod $UPF1 -> Limite ${RATE_EMBB} Mbit/s"
echo "  • UPF2 (URLLC) : Pod $UPF2 -> Limite ${RATE_URLLC} Mbit/s"
echo "  • UPF3 (mMTC)  : Pod $UPF3 -> Limite ${RATE_MMTC} Mbit/s"
echo ""

# --- 4. Fonction de réparation ---
fix_pod() {
    local pod=$1
    local rate=$2
    local label=$3
    
    echo " Traitement de $label ($pod)..."
    
    # A. ACTIVATION IP FORWARDING
    $KUBECTL exec -n $NAMESPACE $pod -- sysctl -w net.ipv4.ip_forward=1 >/dev/null
    echo "   -> IP Forwarding activé"

    # B. RÉPARATION DU ROUTAGE (NAT)
    $KUBECTL exec -n $NAMESPACE $pod -- iptables -t nat -F POSTROUTING
    $KUBECTL exec -n $NAMESPACE $pod -- iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
    echo "   -> NAT (Masquerading) forcé"

    # C. APPLICATION DE LA QoS (SUR TOUTES LES INTERFACES)
    for iface in eth0 tun0 net1; do
        if $KUBECTL exec -n $NAMESPACE $pod -- ip link show $iface >/dev/null 2>&1; then
            # Nettoyage
            $KUBECTL exec -n $NAMESPACE $pod -- tc qdisc del dev $iface root 2>/dev/null || true
            # Application
            $KUBECTL exec -n $NAMESPACE $pod -- tc qdisc add dev $iface root tbf rate "${rate}mbit" burst 128kbit latency 50ms
            echo "   -> QoS appliquée sur $iface : Limite à ${rate}mbit"
        fi
    done
    echo ""
}

# --- 5. Exécution ---
fix_pod "$UPF1" "$RATE_EMBB" "eMBB"
fix_pod "$UPF2" "$RATE_URLLC" "URLLC"
fix_pod "$UPF3" "$RATE_MMTC" "mMTC"

echo "Maintenance terminée."
