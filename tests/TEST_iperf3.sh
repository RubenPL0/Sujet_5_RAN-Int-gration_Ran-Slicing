#!/bin/bash
# =============================================================================
# NexSlice - Tests avec iperf3 Local
# Validation QoS et Core Network Slicing
# =============================================================================

set -e

NAMESPACE="nexslice"
KUBECTL="sudo k3s kubectl"

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[✓]${NC} $1"; }
log_error() { echo -e "${RED}[✗]${NC} $1"; }

# Pods UE
UE1_POD="ueransim-ue1-ueransim-ues-64d67cf8bd-z9kgb"
UE2_POD="ueransim-ue2-ueransim-ues-54bb8968f6-mcrpn"
UE3_POD="ueransim-ue3-ueransim-ues-6d6c959c5b-nqsp4"

# IP serveur iperf3
IPERF_IP=$($KUBECTL get svc -n $NAMESPACE iperf3-svc -o jsonpath='{.spec.clusterIP}')

echo ""
echo "╔══════════════════════════════════════════════════════════════════╗"
echo "║         NexSlice - Tests iperf3 (Core Slicing)                  ║"
echo "╚══════════════════════════════════════════════════════════════════╝"
echo ""

log_info "Serveur iperf3: $IPERF_IP"
echo ""

# =============================================================================
# Test 1: Tests Séquentiels (Baseline)
# =============================================================================

log_info "=========================================="
log_info "Test 1: Débit Séquentiel (30s par UE)"
log_info "=========================================="
echo ""

declare -A THROUGHPUTS_SEQ

# UE1 - eMBB
echo -e "${CYAN}[UE1 - eMBB]${NC} Test iperf3..."
RESULT1=$($KUBECTL exec -n $NAMESPACE $UE1_POD -- \
    iperf3 -c $IPERF_IP -t 30 2>&1 | grep "receiver" | awk '{print $(NF-1)}')

if [ -z "$RESULT1" ]; then
    log_error "Erreur: Impossible de contacter le serveur iperf3"
    log_info "Vérifier: kubectl get svc -n nexslice iperf3-svc"
    exit 1
fi

# Convertir en Mbps
if [[ "$RESULT1" == *"Gbits/sec"* ]]; then
    VALUE=$(echo $RESULT1 | grep -oP '[0-9.]+')
    THROUGHPUTS_SEQ[UE1]=$(awk "BEGIN {printf \"%.2f\", $VALUE * 1000}")
else
    THROUGHPUTS_SEQ[UE1]=$(echo $RESULT1 | grep -oP '[0-9.]+')
fi

# UE2 - URLLC
echo -e "${CYAN}[UE2 - URLLC]${NC} Test iperf3..."
RESULT2=$($KUBECTL exec -n $NAMESPACE $UE2_POD -- \
    iperf3 -c $IPERF_IP -t 30 2>&1 | grep "receiver" | awk '{print $(NF-1)}')

if [[ "$RESULT2" == *"Gbits/sec"* ]]; then
    VALUE=$(echo $RESULT2 | grep -oP '[0-9.]+')
    THROUGHPUTS_SEQ[UE2]=$(awk "BEGIN {printf \"%.2f\", $VALUE * 1000}")
else
    THROUGHPUTS_SEQ[UE2]=$(echo $RESULT2 | grep -oP '[0-9.]+')
fi

# UE3 - mMTC
echo -e "${CYAN}[UE3 - mMTC]${NC} Test iperf3..."
RESULT3=$($KUBECTL exec -n $NAMESPACE $UE3_POD -- \
    iperf3 -c $IPERF_IP -t 30 2>&1 | grep "receiver" | awk '{print $(NF-1)}')

if [[ "$RESULT3" == *"Gbits/sec"* ]]; then
    VALUE=$(echo $RESULT3 | grep -oP '[0-9.]+')
    THROUGHPUTS_SEQ[UE3]=$(awk "BEGIN {printf \"%.2f\", $VALUE * 1000}")
else
    THROUGHPUTS_SEQ[UE3]=$(echo $RESULT3 | grep -oP '[0-9.]+')
fi

echo ""
echo "=============================================="
echo "      RÉSULTATS DÉBIT SÉQUENTIEL (iperf3)   "
echo "=============================================="
printf "%-15s | %-12s | %-15s\n" "UE" "Slice" "Débit (Mbps)"
echo "----------------------------------------------"
printf "%-15s | %-12s | ${GREEN}%15s${NC}\n" "UERANSIM-UE1" "eMBB (100M)" "${THROUGHPUTS_SEQ[UE1]}"
printf "%-15s | %-12s | ${GREEN}%15s${NC}\n" "UERANSIM-UE2" "URLLC (50M)" "${THROUGHPUTS_SEQ[UE2]}"
printf "%-15s | %-12s | ${GREEN}%15s${NC}\n" "UERANSIM-UE3" "mMTC (20M)" "${THROUGHPUTS_SEQ[UE3]}"
echo "=============================================="
echo ""

log_success "Test 1 PASSED: Débits max par slice mesurés"
echo ""

# =============================================================================
# Test 2: Tests Concurrents (Congestion)
# =============================================================================

log_info "=========================================="
log_info "Test 2: Débit Concurrent (60s tous en //)"
log_info "=========================================="
echo ""

log_info "Démarrage des 3 tests iperf3 simultanés..."
echo ""

# Créer répertoire temporaire
TEMP_DIR="/tmp/nexslice_iperf_$$"
mkdir -p $TEMP_DIR

# Lancer en parallèle
(
    $KUBECTL exec -n $NAMESPACE $UE1_POD -- \
        iperf3 -c $IPERF_IP -t 60 2>&1 | grep "receiver" > $TEMP_DIR/ue1.txt
) &
PID1=$!

(
    $KUBECTL exec -n $NAMESPACE $UE2_POD -- \
        iperf3 -c $IPERF_IP -t 60 2>&1 | grep "receiver" > $TEMP_DIR/ue2.txt
) &
PID2=$!

(
    $KUBECTL exec -n $NAMESPACE $UE3_POD -- \
        iperf3 -c $IPERF_IP -t 60 2>&1 | grep "receiver" > $TEMP_DIR/ue3.txt
) &
PID3=$!

# Attendre
echo "Attente de la fin des tests (60s)..."
wait $PID1 $PID2 $PID3

log_success "Tests terminés"
echo ""

# Extraire résultats
CONC_TP1=$(cat $TEMP_DIR/ue1.txt | awk '{print $(NF-1)}' | grep -oP '[0-9.]+')
CONC_TP2=$(cat $TEMP_DIR/ue2.txt | awk '{print $(NF-1)}' | grep -oP '[0-9.]+')
CONC_TP3=$(cat $TEMP_DIR/ue3.txt | awk '{print $(NF-1)}' | grep -oP '[0-9.]+')

rm -rf $TEMP_DIR

echo "=============================================="
echo "    RÉSULTATS DÉBIT CONCURRENT (iperf3)     "
echo "=============================================="
printf "%-15s | %-12s | %-15s | %-10s\n" "UE" "Slice (Limite)" "Débit (Mbps)" "% Max"
echo "--------------------------------------------------------------"

PCT1=$(awk "BEGIN {printf \"%.0f\", ($CONC_TP1 / ${THROUGHPUTS_SEQ[UE1]}) * 100}")
printf "%-15s | %-12s | ${GREEN}%15s${NC} | %9s%%\n" "UERANSIM-UE1" "eMBB (100M)" "$CONC_TP1" "$PCT1"

PCT2=$(awk "BEGIN {printf \"%.0f\", ($CONC_TP2 / ${THROUGHPUTS_SEQ[UE2]}) * 100}")
printf "%-15s | %-12s | ${YELLOW}%15s${NC} | %9s%%\n" "UERANSIM-UE2" "URLLC (50M)" "$CONC_TP2" "$PCT2"

PCT3=$(awk "BEGIN {printf \"%.0f\", ($CONC_TP3 / ${THROUGHPUTS_SEQ[UE3]}) * 100}")
printf "%-15s | %-12s | ${YELLOW}%15s${NC} | %9s%%\n" "UERANSIM-UE3" "mMTC (20M)" "$CONC_TP3" "$PCT3"

echo "=============================================="
echo ""

# Analyse
log_info "Analyse du Core Network Slicing:"

RATIO_12=$(awk "BEGIN {printf \"%.2f\", $CONC_TP1 / $CONC_TP2}")
RATIO_13=$(awk "BEGIN {printf \"%.2f\", $CONC_TP1 / $CONC_TP3}")
RATIO_23=$(awk "BEGIN {printf \"%.2f\", $CONC_TP2 / $CONC_TP3}")

echo "  Ratio eMBB/URLLC: ${RATIO_12}x (limite: 100M/50M = 2x)"
echo "  Ratio eMBB/mMTC:  ${RATIO_13}x (limite: 100M/20M = 5x)"
echo "  Ratio URLLC/mMTC: ${RATIO_23}x (limite: 50M/20M = 2.5x)"
echo ""

if (( $(echo "$RATIO_13 > 3.0" | bc -l) )); then
    log_success "✅ Core Network Slicing fonctionne ! eMBB >> mMTC"
else
    log_info "⚠️  Ratios proches, réseau potentiellement non saturé"
fi

echo ""

# =============================================================================
# Résumé
# =============================================================================

echo "╔══════════════════════════════════════════════════════════════════╗"
echo "║                  RÉSUMÉ TESTS IPERF3                             ║"
echo "╠══════════════════════════════════════════════════════════════════╣"
echo "║                                                                  ║"
echo "║  Tests Séquentiels (Baseline):                                  ║"
echo "║    • eMBB (100M):  ${THROUGHPUTS_SEQ[UE1]} Mbps                              ║"
echo "║    • URLLC (50M):  ${THROUGHPUTS_SEQ[UE2]} Mbps                              ║"
echo "║    • mMTC (20M):   ${THROUGHPUTS_SEQ[UE3]} Mbps                              ║"
echo "║                                                                  ║"
echo "║  Tests Concurrents (Congestion):                                ║"
echo "║    • eMBB:  $CONC_TP1 Mbps ($PCT1% du max)                        ║"
echo "║    • URLLC: $CONC_TP2 Mbps ($PCT2% du max)                        ║"
echo "║    • mMTC:  $CONC_TP3 Mbps ($PCT3% du max)                        ║"
echo "║                                                                  ║"
echo "║  Ratios Observés:                                               ║"
echo "║    • eMBB/URLLC: ${RATIO_12}x                                           ║"
echo "║    • eMBB/mMTC:  ${RATIO_13}x                                           ║"
echo "║    • URLLC/mMTC: ${RATIO_23}x                                           ║"
echo "║                                                                  ║"
echo "╚══════════════════════════════════════════════════════════════════╝"
echo ""

log_success "Tests iperf3 terminés! 🎉"
echo ""
