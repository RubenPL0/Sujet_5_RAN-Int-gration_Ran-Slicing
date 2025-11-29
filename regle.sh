#!/bin/bash
# =============================================================================
# NexSlice - Amélioration Tests avec iperf3 Local + QoS
# Démonstration claire du Core Network Slicing
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
log_warning() { echo -e "${YELLOW}[!]${NC} $1"; }
log_error() { echo -e "${RED}[✗]${NC} $1"; }

echo ""
echo "╔══════════════════════════════════════════════════════════════════╗"
echo "║     NexSlice - Configuration Tests Améliorés                    ║"
echo "╚══════════════════════════════════════════════════════════════════╝"
echo ""

# =============================================================================
# Étape 1: Déployer Serveur iperf3
# =============================================================================

log_info "Étape 1: Déploiement serveur iperf3 local"
echo ""

# Vérifier si déjà déployé
if $KUBECTL get pod -n $NAMESPACE iperf3-server 2>/dev/null | grep -q "Running"; then
    log_info "Serveur iperf3 déjà déployé"
else
    log_info "Création du serveur iperf3..."
    
    # Créer le pod iperf3
    $KUBECTL run iperf3-server -n $NAMESPACE \
        --image=networkstatic/iperf3 \
        --port=5201 \
        --restart=Always \
        -- -s -p 5201
    
    # Attendre que le pod démarre
    log_info "Attente du démarrage du pod..."
    sleep 10
    
    # Exposer le service
    $KUBECTL expose pod iperf3-server -n $NAMESPACE \
        --port=5201 \
        --target-port=5201 \
        --name=iperf3-svc 2>/dev/null || log_info "Service déjà exposé"
    
    sleep 5
fi

# Vérifier le statut
IPERF_STATUS=$($KUBECTL get pod -n $NAMESPACE iperf3-server -o jsonpath='{.status.phase}' 2>/dev/null || echo "NotFound")

if [ "$IPERF_STATUS" = "Running" ]; then
    log_success "Serveur iperf3 opérationnel"
    IPERF_IP=$($KUBECTL get svc -n $NAMESPACE iperf3-svc -o jsonpath='{.spec.clusterIP}')
    log_info "IP du serveur: $IPERF_IP"
else
    log_error "Problème avec le serveur iperf3"
    exit 1
fi

echo ""

# =============================================================================
# Étape 2: Appliquer Limitations QoS sur les UPFs
# =============================================================================

log_info "Étape 2: Application des limitations de bande passante (QoS)"
echo ""

log_warning "Cette étape va limiter la bande passante de chaque UPF pour simuler la QoS:"
log_info "  • UPF1 (eMBB):  100 Mbps (priorité haute)"
log_info "  • UPF2 (URLLC): 50 Mbps  (priorité moyenne)"
log_info "  • UPF3 (mMTC):  20 Mbps  (priorité basse)"
echo ""

read -p "Appliquer les limitations ? (o/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Oo]$ ]]; then
    
    # UPF1 - eMBB (100 Mbps)
    log_info "Configuration UPF1 (eMBB): 100 Mbps..."
    UPF1_POD=$($KUBECTL get pods -n $NAMESPACE -l app.kubernetes.io/name=oai-upf -o jsonpath='{.items[0].metadata.name}')
    
    # Supprimer l'ancien qdisc si existe
    $KUBECTL exec -n $NAMESPACE $UPF1_POD -- tc qdisc del dev eth0 root 2>/dev/null || true
    
    # Appliquer nouvelle limite
    $KUBECTL exec -n $NAMESPACE $UPF1_POD -- \
        tc qdisc add dev eth0 root tbf rate 100mbit burst 128kbit latency 50ms
    log_success "UPF1 limité à 100 Mbps"
    
    # UPF2 - URLLC (50 Mbps)
    log_info "Configuration UPF2 (URLLC): 50 Mbps..."
    UPF2_POD=$($KUBECTL get pods -n $NAMESPACE -l app.kubernetes.io/name=oai-upf2 -o jsonpath='{.items[0].metadata.name}')
    
    $KUBECTL exec -n $NAMESPACE $UPF2_POD -- tc qdisc del dev eth0 root 2>/dev/null || true
    $KUBECTL exec -n $NAMESPACE $UPF2_POD -- \
        tc qdisc add dev eth0 root tbf rate 50mbit burst 64kbit latency 50ms
    log_success "UPF2 limité à 50 Mbps"
    
    # UPF3 - mMTC (20 Mbps)
    log_info "Configuration UPF3 (mMTC): 20 Mbps..."
    UPF3_POD=$($KUBECTL get pods -n $NAMESPACE -l app.kubernetes.io/name=oai-upf3 -o jsonpath='{.items[0].metadata.name}')
    
    $KUBECTL exec -n $NAMESPACE $UPF3_POD -- tc qdisc del dev eth0 root 2>/dev/null || true
    $KUBECTL exec -n $NAMESPACE $UPF3_POD -- \
        tc qdisc add dev eth0 root tbf rate 20mbit burst 32kbit latency 100ms
    log_success "UPF3 limité à 20 Mbps"
    
    echo ""
    log_success "Limitations QoS appliquées avec succès!"
    
else
    log_info "Limitations QoS non appliquées (test sans QoS)"
fi

echo ""

# =============================================================================
# Étape 3: Créer le Script de Test Amélioré
# =============================================================================

log_info "Étape 3: Création du script de test amélioré"
echo ""

cat > tests/TEST_iperf3.sh <<'EOFTEST'
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

# Pods UE
UE1_POD="ueransim-ue1-ueransim-ues-64d67cf8bd-z9kgb"
UE2_POD="ueransim-ue2-ueransim-ues-54bb8968f6-mcrpn"
UE3_POD="ueransim-ue3-ueransim-ues-6d6c959c5b-nqsp4"

# IP serveur iperf3
IPERF_SVC="iperf3-svc.nexslice.svc.cluster.local"

echo ""
echo "╔══════════════════════════════════════════════════════════════════╗"
echo "║         NexSlice - Tests iperf3 (Core Slicing)                  ║"
echo "╚══════════════════════════════════════════════════════════════════╝"
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
    iperf3 -c $IPERF_SVC -t 30 -J 2>/dev/null | grep -oP '"sum_received".*"bits_per_second":\K[0-9.]+' | head -1)
THROUGHPUTS_SEQ[UE1]=$(awk "BEGIN {printf \"%.2f\", $RESULT1 / 1000000}")

# UE2 - URLLC
echo -e "${CYAN}[UE2 - URLLC]${NC} Test iperf3..."
RESULT2=$($KUBECTL exec -n $NAMESPACE $UE2_POD -- \
    iperf3 -c $IPERF_SVC -t 30 -J 2>/dev/null | grep -oP '"sum_received".*"bits_per_second":\K[0-9.]+' | head -1)
THROUGHPUTS_SEQ[UE2]=$(awk "BEGIN {printf \"%.2f\", $RESULT2 / 1000000}")

# UE3 - mMTC
echo -e "${CYAN}[UE3 - mMTC]${NC} Test iperf3..."
RESULT3=$($KUBECTL exec -n $NAMESPACE $UE3_POD -- \
    iperf3 -c $IPERF_SVC -t 30 -J 2>/dev/null | grep -oP '"sum_received".*"bits_per_second":\K[0-9.]+' | head -1)
THROUGHPUTS_SEQ[UE3]=$(awk "BEGIN {printf \"%.2f\", $RESULT3 / 1000000}")

echo ""
echo "=============================================="
echo "      RÉSULTATS DÉBIT SÉQUENTIEL (iperf3)   "
echo "=============================================="
printf "%-15s | %-12s | %-15s\n" "UE" "Slice" "Débit (Mbps)"
echo "----------------------------------------------"
printf "%-15s | %-12s | ${GREEN}%15.2f${NC}\n" "UERANSIM-UE1" "eMBB (100M)" "${THROUGHPUTS_SEQ[UE1]}"
printf "%-15s | %-12s | ${GREEN}%15.2f${NC}\n" "UERANSIM-UE2" "URLLC (50M)" "${THROUGHPUTS_SEQ[UE2]}"
printf "%-15s | %-12s | ${GREEN}%15.2f${NC}\n" "UERANSIM-UE3" "mMTC (20M)" "${THROUGHPUTS_SEQ[UE3]}"
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
        iperf3 -c $IPERF_SVC -t 60 -J 2>/dev/null > $TEMP_DIR/ue1.json
) &
PID1=$!

(
    $KUBECTL exec -n $NAMESPACE $UE2_POD -- \
        iperf3 -c $IPERF_SVC -t 60 -J 2>/dev/null > $TEMP_DIR/ue2.json
) &
PID2=$!

(
    $KUBECTL exec -n $NAMESPACE $UE3_POD -- \
        iperf3 -c $IPERF_SVC -t 60 -J 2>/dev/null > $TEMP_DIR/ue3.json
) &
PID3=$!

# Attendre
echo "Attente de la fin des tests (60s)..."
wait $PID1 $PID2 $PID3

log_success "Tests terminés"
echo ""

# Extraire résultats
CONC_TP1=$(cat $TEMP_DIR/ue1.json | grep -oP '"sum_received".*"bits_per_second":\K[0-9.]+' | head -1)
CONC_TP1_MBPS=$(awk "BEGIN {printf \"%.2f\", $CONC_TP1 / 1000000}")

CONC_TP2=$(cat $TEMP_DIR/ue2.json | grep -oP '"sum_received".*"bits_per_second":\K[0-9.]+' | head -1)
CONC_TP2_MBPS=$(awk "BEGIN {printf \"%.2f\", $CONC_TP2 / 1000000}")

CONC_TP3=$(cat $TEMP_DIR/ue3.json | grep -oP '"sum_received".*"bits_per_second":\K[0-9.]+' | head -1)
CONC_TP3_MBPS=$(awk "BEGIN {printf \"%.2f\", $CONC_TP3 / 1000000}")

rm -rf $TEMP_DIR

echo "=============================================="
echo "    RÉSULTATS DÉBIT CONCURRENT (iperf3)     "
echo "=============================================="
printf "%-15s | %-12s | %-15s | %-10s\n" "UE" "Slice (Limite)" "Débit (Mbps)" "% Max"
echo "--------------------------------------------------------------"

PCT1=$(awk "BEGIN {printf \"%.0f\", ($CONC_TP1_MBPS / ${THROUGHPUTS_SEQ[UE1]}) * 100}")
printf "%-15s | %-12s | ${GREEN}%15.2f${NC} | %9s%%\n" "UERANSIM-UE1" "eMBB (100M)" "$CONC_TP1_MBPS" "$PCT1"

PCT2=$(awk "BEGIN {printf \"%.0f\", ($CONC_TP2_MBPS / ${THROUGHPUTS_SEQ[UE2]}) * 100}")
printf "%-15s | %-12s | ${YELLOW}%15.2f${NC} | %9s%%\n" "UERANSIM-UE2" "URLLC (50M)" "$CONC_TP2_MBPS" "$PCT2"

PCT3=$(awk "BEGIN {printf \"%.0f\", ($CONC_TP3_MBPS / ${THROUGHPUTS_SEQ[UE3]}) * 100}")
printf "%-15s | %-12s | ${YELLOW}%15.2f${NC} | %9s%%\n" "UERANSIM-UE3" "mMTC (20M)" "$CONC_TP3_MBPS" "$PCT3"

echo "=============================================="
echo ""

# Analyse
log_info "Analyse du Core Network Slicing:"

RATIO_12=$(awk "BEGIN {printf \"%.2f\", $CONC_TP1_MBPS / $CONC_TP2_MBPS}")
RATIO_13=$(awk "BEGIN {printf \"%.2f\", $CONC_TP1_MBPS / $CONC_TP3_MBPS}")
RATIO_23=$(awk "BEGIN {printf \"%.2f\", $CONC_TP2_MBPS / $CONC_TP3_MBPS}")

echo "  Ratio eMBB/URLLC: ${RATIO_12}x (limite: 100M/50M = 2x)"
echo "  Ratio eMBB/mMTC:  ${RATIO_13}x (limite: 100M/20M = 5x)"
echo "  Ratio URLLC/mMTC: ${RATIO_23}x (limite: 50M/20M = 2.5x)"
echo ""

if (( $(echo "$RATIO_13 > 3.0" | bc -l) )); then
    log_success "✅ Core Network Slicing fonctionne ! eMBB >> mMTC"
else
    log_info "⚠️  Ratios proches, augmenter la durée du test ou la charge"
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
echo "║    • eMBB:  $CONC_TP1_MBPS Mbps ($PCT1% du max)                        ║"
echo "║    • URLLC: $CONC_TP2_MBPS Mbps ($PCT2% du max)                        ║"
echo "║    • mMTC:  $CONC_TP3_MBPS Mbps ($PCT3% du max)                        ║"
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
EOFTEST

chmod +x tests/TEST_iperf3.sh

log_success "Script de test iperf3 créé: tests/TEST_iperf3.sh"
echo ""

# =============================================================================
# Étape 4: Créer Script de Nettoyage
# =============================================================================

log_info "Étape 4: Création du script de nettoyage"
echo ""

cat > tests/cleanup_iperf3.sh <<'EOFCLEAN'
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
EOFCLEAN

chmod +x tests/cleanup_iperf3.sh

log_success "Script de nettoyage créé: tests/cleanup_iperf3.sh"
echo ""

# =============================================================================
# Résumé
# =============================================================================

echo ""
echo "╔══════════════════════════════════════════════════════════════════╗"
echo "║              Configuration Terminée avec Succès!                ║"
echo "╚══════════════════════════════════════════════════════════════════╝"
echo ""
echo "✅ Serveur iperf3 déployé"
echo "✅ Limitations QoS configurées (si activées)"
echo "✅ Script de test créé"
echo "✅ Script de nettoyage créé"
echo ""
echo "📊 Configuration QoS Active:"
echo "   • UPF1 (eMBB):  100 Mbps"
echo "   • UPF2 (URLLC): 50 Mbps"
echo "   • UPF3 (mMTC):  20 Mbps"
echo ""
echo "🚀 Lancer les tests maintenant:"
echo "   ./tests/TEST_iperf3.sh"
echo ""
echo "🧹 Pour nettoyer après les tests:"
echo "   ./tests/cleanup_iperf3.sh"
echo ""