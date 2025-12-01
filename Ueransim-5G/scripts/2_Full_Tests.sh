#!/bin/bash
# =============================================================================
# NexSlice - Tests iperf3 (VERSION FINALE AVEC RATIOS)
# =============================================================================

# 1. SOLUTION PROBLÈME DE VIRGULE : Forcer la locale numérique en Anglais
export LC_NUMERIC=C

set +e  # Ne pas arrêter sur erreurs

NAMESPACE="nexslice"
KUBECTL="sudo k3s kubectl"

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${BLUE}[INFO]${NC} $1"; }
ok()  { echo -e "${GREEN}[OK]${NC} $1"; }
err() { echo -e "${RED}[ERR]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }

clear
echo "╔══════════════════════════════════════════════════════════════════╗"
echo "║         NexSlice - Tests iperf3 (Core Slicing)                   ║"
echo "╚══════════════════════════════════════════════════════════════════╝"
echo ""

# =============================================================================
# 1. Préparation
# =============================================================================

log "Identification des pods..."

TRAFFIC=$($KUBECTL get pod -n $NAMESPACE -l app.kubernetes.io/name=oai-traffic-server -o jsonpath='{.items[0].metadata.name}')
UE1=$($KUBECTL get pod -n $NAMESPACE -l app.kubernetes.io/instance=ueransim-ue1 -o jsonpath='{.items[0].metadata.name}')
UE2=$($KUBECTL get pod -n $NAMESPACE -l app.kubernetes.io/instance=ueransim-ue2 -o jsonpath='{.items[0].metadata.name}')
UE3=$($KUBECTL get pod -n $NAMESPACE -l app.kubernetes.io/instance=ueransim-ue3 -o jsonpath='{.items[0].metadata.name}')

# Récupération IP Serveur Traffic
TRAFFIC_IP=$($KUBECTL get pod -n $NAMESPACE $TRAFFIC -o jsonpath='{.status.podIP}')

echo "  Traffic: $TRAFFIC ($TRAFFIC_IP)"
echo "  UE1: $UE1"
echo "  UE2: $UE2"
echo "  UE3: $UE3"
echo ""

# Installer iperf3 dans traffic server
log "Installation iperf3 dans traffic-server..."
$KUBECTL exec -n $NAMESPACE $TRAFFIC -- which iperf3 >/dev/null 2>&1 || \
  $KUBECTL exec -n $NAMESPACE $TRAFFIC -- bash -c "apt-get update >/dev/null 2>&1 && apt-get install -y iperf3 >/dev/null 2>&1"

# Lancer 3 serveurs sur 3 ports différents
log "Démarrage de 3 instances iperf3 sur le traffic-server..."
$KUBECTL exec -n $NAMESPACE $TRAFFIC -- pkill -9 iperf3 2>/dev/null
sleep 2
$KUBECTL exec -n $NAMESPACE $TRAFFIC -- bash -c "iperf3 -s -p 5201 -D"
$KUBECTL exec -n $NAMESPACE $TRAFFIC -- bash -c "iperf3 -s -p 5202 -D"
$KUBECTL exec -n $NAMESPACE $TRAFFIC -- bash -c "iperf3 -s -p 5203 -D"
sleep 10 #laisser le temps aux serveurs de démarrer
echo ""

# Test connectivité
log "Test de connectivité 5G..."
if ! $KUBECTL exec -n $NAMESPACE $UE1 -- ping -I uesimtun0 -c 2 -W 3 $TRAFFIC_IP >/dev/null 2>&1; then
    err "UE1 ne peut pas joindre traffic-server via la 5G (uesimtun0)"
    echo "DEBUG: Interfaces disponibles :"
    $KUBECTL exec -n $NAMESPACE $UE1 -- ip addr
    echo ""
    echo " Faites kubectl delete pods --all -n nexslice pour redémarrer les pods. Puis relancez les scripts de test." 
    echo " Si ça ne marche toujours pas, vérifiez que le HPA n'a pas augmenté le nombre de UPF entre temps." 
    exit 1
fi
ok "Connectivité 5G OK"
echo ""


# =============================================================================
# 2. Test Séquentiel
# =============================================================================

log "================================================"
log "TEST 1: Débit Séquentiel (10s par UE)"
log "================================================"
echo ""

test_ue() {
    local pod=$1
    local label=$2
    local port=$3
    
    echo -n "  $label ... " >&2
    UE_IP=$($KUBECTL exec -n $NAMESPACE $pod -- ip -4 addr show uesimtun0 2>/dev/null | grep -oP '(?<=inet\s)\d+(\.\d+){3}')

    if [ -z "$UE_IP" ]; then echo "ÉCHEC (Pas d'IP 5G)" >&2; echo "0"; return; fi

    result=$($KUBECTL exec -n $NAMESPACE $pod -- iperf3 -c $TRAFFIC_IP --bind $UE_IP -p $port -t 10 --json 2>/dev/null)
    val=$(echo "$result" | python3 -c "import sys, json; print(json.load(sys.stdin)['end']['sum_received']['bits_per_second'])" 2>/dev/null)

    if [ -n "$val" ]; then
        mbps=$(echo "scale=2; $val / 1000000" | bc)
        echo "${mbps} Mbps" >&2
        echo "$mbps"
    else
        echo "ERREUR Iperf" >&2; echo "0"
    fi
}

SEQ1=$(test_ue "$UE1" "UE1 (eMBB)" "5201")
sleep 1
SEQ2=$(test_ue "$UE2" "UE2 (URLLC)" "5202")
sleep 1
SEQ3=$(test_ue "$UE3" "UE3 (mMTC)" "5203")

echo ""
echo "RÉSULTATS SÉQUENTIELS:"
echo "  UE1 (eMBB):  $SEQ1 Mbps"
echo "  UE2 (URLLC): $SEQ2 Mbps"
echo "  UE3 (mMTC):  $SEQ3 Mbps"
echo ""
ok "Test 1 terminé"
echo ""

# =============================================================================
# 3. Test Concurrent
# =============================================================================

log "================================================"
log "TEST 2: Débit Concurrent (30s, tous en //)"
log "================================================"
echo ""

TMP="/tmp/iperf_test_$$"
mkdir -p $TMP

IP_UE1=$($KUBECTL exec -n $NAMESPACE $UE1 -- ip -4 addr show uesimtun0 | grep -oP '(?<=inet\s)\d+(\.\d+){3}')
IP_UE2=$($KUBECTL exec -n $NAMESPACE $UE2 -- ip -4 addr show uesimtun0 | grep -oP '(?<=inet\s)\d+(\.\d+){3}')
IP_UE3=$($KUBECTL exec -n $NAMESPACE $UE3 -- ip -4 addr show uesimtun0 | grep -oP '(?<=inet\s)\d+(\.\d+){3}')

log "Lancement des 3 tests simultanés via 5G..."

$KUBECTL exec -n $NAMESPACE $UE1 -- iperf3 -c $TRAFFIC_IP --bind $IP_UE1 -p 5201 -t 30 --json > $TMP/ue1.json 2>/dev/null &
P1=$!
$KUBECTL exec -n $NAMESPACE $UE2 -- iperf3 -c $TRAFFIC_IP --bind $IP_UE2 -p 5202 -t 30 --json > $TMP/ue2.json 2>/dev/null &
P2=$!
$KUBECTL exec -n $NAMESPACE $UE3 -- iperf3 -c $TRAFFIC_IP --bind $IP_UE3 -p 5203 -t 30 --json > $TMP/ue3.json 2>/dev/null &
P3=$!

log "Tests en cours (30s)..."
wait $P1 $P2 $P3

ok "Tests terminés"
echo ""

extract_json() {
    local file=$1
    if [ ! -s $file ]; then echo "0"; return; fi
    val=$(cat $file | python3 -c "import sys, json; print(json.load(sys.stdin)['end']['sum_received']['bits_per_second'])" 2>/dev/null)
    if [ -z "$val" ]; then echo "0"; else echo "scale=2; $val / 1000000" | bc; fi
}

CONC1=$(extract_json $TMP/ue1.json)
CONC2=$(extract_json $TMP/ue2.json)
CONC3=$(extract_json $TMP/ue3.json)
rm -rf $TMP

echo "RÉSULTATS CONCURRENTS:"
echo "  UE1 (eMBB):  $CONC1 Mbps"
echo "  UE2 (URLLC): $CONC2 Mbps"
echo "  UE3 (mMTC):  $CONC3 Mbps"
echo ""

# =============================================================================
# 4. Analyse et Ratios
# =============================================================================

# =============================================================================
# Calibration de la capacité machine (UDP) 
# =============================================================================


log "Calibration : Mesure de la capacité maximale de la machine (Test UDP)..."
IP_CALIB=$($KUBECTL exec -n $NAMESPACE $UE1 -- ip -4 addr show uesimtun0 2>/dev/null | grep -oP '(?<=inet\s)\d+(\.\d+){3}')

if [ -z "$IP_CALIB" ]; then
    MAX_CAPACITY=100
else
    # 1. On lance le test UDP saturation
    CALIB_RES=$(timeout 15s $KUBECTL exec -n $NAMESPACE $UE1 -- iperf3 -c $TRAFFIC_IP --bind $IP_CALIB -p 5201 -u -b 200M -R -t 5 --json 2>/dev/null)
    
    # 2. CALCUL DU DÉBIT RÉEL (Reçu = Envoyé - Pertes)
    VAL_CALIB=$(echo "$CALIB_RES" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    stats = d['end']['sum']
    
    # Récupération des valeurs brutes
    bps = stats['bits_per_second']
    loss = stats['lost_percent']
    
    # Si le débit affiché est proche de la cible (ex: 199Mbps) avec des pertes,
    # c'est que iperf affiche le débit envoyé. On corrige manuellement.
    # Formule : Débit * (1 - (Perte / 100))
    real_bps = bps * (1 - (loss / 100))
    
    print(real_bps)
except:
    print('')
" 2>/dev/null)
    
    if [ -n "$VAL_CALIB" ]; then
        MAX_CAPACITY=$(echo "scale=2; $VAL_CALIB / 1000000" | bc)
        ok "Capacité physique mesurée (Reçue) : $MAX_CAPACITY Mbps"
    else
        warn "Échec calibration UDP, utilisation valeur par défaut."
        MAX_CAPACITY=102.0 #valeur obtenue avec mes derniers tests 
    fi
fi
echo ""

log "ANALYSE DU CORE NETWORK SLICING:"
echo ""

RATIO_TCP_UDP=$(echo "$SEQ1 / $MAX_CAPACITY" | bc -l)
TOTAL_CONC=$(echo "$CONC1 + $CONC2 + $CONC3" | bc)

echo "----------------------------------------------------------------"
echo "                        INTERPRÉTATION                          "
echo "----------------------------------------------------------------"
echo -e "${BLUE}[ANALYSE]${NC} Capacité physique du lien (UDP) : $MAX_CAPACITY Mbps."
echo -e "          Débit eMBB obtenu (TCP) : $SEQ1 Mbps."

if (( $(echo "$RATIO_TCP_UDP < 0.75" | bc -l) )); then
    echo "          -> Le débit TCP est inférieur à 75% de la capacité physique (Latence CPU). En effet, TCP n'utilise pas toute la bande passante disponible par sécurité."
else
    echo "          -> Le débit TCP est proche de la capacité physique."
fi

if (( $(echo "$SEQ3 <= 22" | bc -l) )); then
    echo -e "${GREEN}[SUCCÈS]${NC}  Le slice mMTC ($SEQ3 Mbps) respecte sa QoS (~20 Mbps)."
else
    echo -e "${YELLOW}[WARN]${NC}    Le slice mMTC ($SEQ3 Mbps) dépasse la limite prévue."
fi

if (( $(echo "$CONC1 > $CONC3" | bc -l) )); then
     echo "          Isolation validée : eMBB ($CONC1) > mMTC ($CONC3) en charge."
fi
echo "----------------------------------------------------------------"
echo ""

# Calcul des Ratios pour l'affichage final
QOS1=50
QOS2=50
QOS3=20

# Sécurité division par zéro
if (( $(echo "$CONC2 > 0" | bc -l) )); then RATIO_12=$(awk "BEGIN {printf \"%.2f\", $CONC1 / $CONC2}"); else RATIO_12="Inf"; fi
if (( $(echo "$CONC3 > 0" | bc -l) )); then RATIO_13=$(awk "BEGIN {printf \"%.2f\", $CONC1 / $CONC3}"); else RATIO_13="Inf"; fi

THEO_12=$(awk "BEGIN {printf \"%.2f\", $QOS1 / $QOS2}")
THEO_13=$(awk "BEGIN {printf \"%.2f\", $QOS1 / $QOS3}")

echo "╔══════════════════════════════════════════════════════════════════╗"
echo "║                       RÉSUMÉ FINAL                               ║"
echo "╠══════════════════════════════════════════════════════════════════╣"
printf "║  Séquentiel:  eMBB=%6.1f  URLLC=%6.1f  mMTC=%6.1f Mbps        ║\n" "$SEQ1" "$SEQ2" "$SEQ3"
printf "║  Concurrent:  eMBB=%6.1f  URLLC=%6.1f  mMTC=%6.1f Mbps        ║\n" "$CONC1" "$CONC2" "$CONC3"
echo "╠══════════════════════════════════════════════════════════════════╣"
echo "║                    ANALYSE DES RATIOS                            ║"
echo "╠══════════════════════════════════════════════════════════════════╣"
printf "║ eMBB/URLLC  : ${YELLOW}%-6s${NC}  (Cible QoS: %-5s)                         ║\n" "${RATIO_12}x" "${THEO_12}x"
printf "║ eMBB/mMTC   : ${YELLOW}%-6s${NC}  (Cible QoS: %-5s)                         ║\n" "${RATIO_13}x" "${THEO_13}x"
echo "╚══════════════════════════════════════════════════════════════════╝"
echo ""

ok "${GREEN} Tests terminés !${NC}"
echo ""
