#!/bin/bash
# =============================================================================
# Script Automatisé : Connexion gNB OAI ↔ Core 5G Kubernetes
# =============================================================================

set -e

NAMESPACE="nexslice"
KUBECTL="sudo k3s kubectl"
OAI_DIR="$HOME/NexSlice/ORANSlice/oai_ran"

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

clear
echo ""
echo "╔══════════════════════════════════════════════════════════════════╗"
echo "║    Connexion Automatique : gNB OAI ↔ Core 5G Kubernetes         ║"
echo "╚══════════════════════════════════════════════════════════════════╝"
echo ""

# =============================================================================
# Étape 1 : Vérifier les Prérequis
# =============================================================================

log_info "Étape 1/7: Vérification des prérequis"
echo ""

# Vérifier que le Core est UP
if ! $KUBECTL get pods -n $NAMESPACE &>/dev/null; then
    log_error "Kubernetes n'est pas accessible"
    exit 1
fi

AMF_POD=$($KUBECTL get pods -n $NAMESPACE -l app.kubernetes.io/name=oai-amf -o jsonpath='{.items[0].metadata.name}')
if [ -z "$AMF_POD" ]; then
    log_error "AMF pod non trouvé dans le namespace $NAMESPACE"
    exit 1
fi

log_success "Core 5G détecté (AMF: $AMF_POD)"

# Vérifier OAI compilé
if [ ! -f "$OAI_DIR/cmake_targets/ran_build/build/nr-softmodem" ]; then
    log_error "gNB OAI non compilé dans $OAI_DIR"
    exit 1
fi

log_success "Binaires OAI trouvés"
echo ""

# =============================================================================
# Étape 2 : Tuer les anciens processus
# =============================================================================

log_info "Étape 2/7: Nettoyage des anciens processus"
echo ""

# Tuer anciens gNB/UE
sudo pkill -9 nr-softmodem 2>/dev/null || true
sudo pkill -9 nr-uesoftmodem 2>/dev/null || true

# Tuer anciens port-forward
pkill -f "port-forward.*38412" 2>/dev/null || true

sleep 2
log_success "Processus nettoyés"
echo ""

# =============================================================================
# Étape 3 : Port-forward AMF (CORRIGÉ)
# =============================================================================

log_info "Étape 3/7: Exposition de l'AMF (port 38412)"
echo ""

# Démarrer port-forward en arrière-plan
$KUBECTL port-forward -n $NAMESPACE svc/oai-amf 38412:38412 --address 0.0.0.0 > /tmp/amf-portforward.log 2>&1 &
PF_PID=$! # Capture le PID du processus d'arrière-plan

sleep 3 # Laisser le temps de démarrer

# Vérifier si le port est en écoute avec 'ss'
if sudo ss -tuln 2>/dev/null | grep -q ":38412"; then
    log_success "AMF exposé sur 127.0.0.1:38412 (PID: $PF_PID)"
    echo "$PF_PID" > /tmp/amf-portforward.pid
    echo ""
else
    log_error "Port-forward AMF a échoué (port non écouté)."
    cat /tmp/amf-portforward.log
    # Tuer le processus d'arrière-plan au cas où il serait toujours là mais non fonctionnel
    kill $PF_PID 2>/dev/null || true
    exit 1
fi

# =============================================================================
# Étape 4 : Modifier Config gNB
# =============================================================================

log_info "Étape 4/7: Modification de la configuration gNB"
echo ""

GNB_CONF="$OAI_DIR/targets/PROJECTS/GENERIC-NR-5GC/CONF/gnb.sa.band78.fr1.106PRB.usrpb210.conf"

# Backup
cp "$GNB_CONF" "$GNB_CONF.bak.$(date +%s)" 2>/dev/null || true

# Modifier IP AMF vers 127.0.0.1
sed -i 's/ipv4[[:space:]]*=[[:space:]]*"192\.168\.70\.132"/ipv4       = "127.0.0.1"/' "$GNB_CONF"

# Vérifier
if grep -q 'ipv4.*127\.0\.0\.1' "$GNB_CONF"; then
    log_success "Config gNB modifiée (AMF → 127.0.0.1)"
else
    log_warning "Config non modifiée, mais on continue..."
fi

echo ""

# =============================================================================
# Étape 5 : Enregistrer UE dans la Base MySQL
# =============================================================================

log_info "Étape 5/7: Enregistrement du UE dans la base de données"
echo ""

MYSQL_POD=$($KUBECTL get pods -n $NAMESPACE -l app.kubernetes.io/name=5gc-mysql -o jsonpath='{.items[0].metadata.name}')

if [ -z "$MYSQL_POD" ]; then
    log_warning "MySQL pod non trouvé, UE peut ne pas s'authentifier"
else
    log_info "MySQL pod: $MYSQL_POD"
    
    # Créer script SQL
    cat > /tmp/add_ue.sql <<'EOSQL'
USE oai_db;

-- Supprimer si existe déjà
DELETE FROM AuthenticationSubscription WHERE ueid='208990000000001';
DELETE FROM SessionManagementSubscriptionData WHERE ueid='208990000000001';
DELETE FROM AccessAndMobilitySubscriptionData WHERE ueid='208990000000001';

-- Ajouter UE
INSERT INTO AuthenticationSubscription (ueid, authenticationMethod, encPermanentKey, protectionParameterId, sequenceNumber, authenticationManagementField, algorithmId, encOpcKey, encTopcKey, vectorGenerationInHss, n5gcAuthMethod, rgAuthenticationInd, supi) 
VALUES ('208990000000001', '5G_AKA', 'fec86ba6eb707ed08905757b1bb44b8f', 'fec86ba6eb707ed08905757b1bb44b8f', '{\"sqn\": \"000000000020\", \"sqnScheme\": \"NON_TIME_BASED\", \"lastIndexes\": {\"ausf\": 0}}', '8000', 'milenage', 'C42449363BBAD02B66D16BC975D77CC1', NULL, NULL, NULL, NULL, '208990000000001');

INSERT INTO SessionManagementSubscriptionData (ueid, servingPlmnid, singleNssai, dnnConfigurations) 
VALUES ('208990000000001', '20899', '{\"sst\": 1, \"sd\": \"ffffff\"}', '{\"oai\":{\"pduSessionTypes\":{ \"defaultSessionType\": \"IPV4\"},\"sscModes\": {\"defaultSscMode\": \"SSC_MODE_1\"},\"5gQosProfile\": {\"5qi\": 9,\"arp\":{\"priorityLevel\": 15,\"preemptCap\": \"NOT_PREEMPT\",\"preemptVuln\":\"NOT_PREEMPTABLE\"},\"priorityLevel\":1},\"sessionAmbr\":{\"uplink\":\"100Mbps\", \"downlink\":\"100Mbps\"}}}');

INSERT INTO AccessAndMobilitySubscriptionData (ueid, servingPlmnid, subscribedUeAmbr, nssai) 
VALUES ('208990000000001', '20899', '{\"uplink\":\"100Mbps\",\"downlink\":\"100Mbps\"}', '{\"defaultSingleNssais\": [{\"sst\": 1, \"sd\": \"ffffff\"}]}');
EOSQL

    # Copier dans le pod et exécuter
    $KUBECTL cp /tmp/add_ue.sql $NAMESPACE/$MYSQL_POD:/tmp/add_ue.sql
    $KUBECTL exec -n $NAMESPACE $MYSQL_POD -- mysql -u root -plinux < /tmp/add_ue.sql 2>/dev/null
    
    # Vérifier
    RESULT=$($KUBECTL exec -n $NAMESPACE $MYSQL_POD -- mysql -u root -plinux -e "SELECT ueid FROM oai_db.AuthenticationSubscription WHERE ueid='208990000000001';" 2>/dev/null | grep -c "208990000000001" || echo "0")
    
    if [ "$RESULT" = "1" ]; then
        log_success "UE 208990000000001 enregistré dans la base"
    else
        log_warning "UE peut ne pas être enregistré correctement"
    fi
fi

echo ""

# =============================================================================
# Étape 6 : Créer Interface Réseau
# =============================================================================

log_info "Étape 6/7: Configuration interface réseau"
echo ""

# Supprimer ancienne interface
sudo ip link del demo-oai 2>/dev/null || true

# Créer interface dummy
sudo ip link add demo-oai type dummy
sudo ip addr add 192.168.70.129/24 dev demo-oai
sudo ip link set demo-oai up

log_success "Interface demo-oai créée (192.168.70.129/24)"
echo ""

# =============================================================================
# Étape 7 : Créer Scripts de Lancement
# =============================================================================

log_info "Étape 7/7: Création des scripts de lancement"
echo ""

# Script gNB
cat > /tmp/start_gnb_oai.sh <<'EOFGNB'
#!/bin/bash
cd $HOME/NexSlice/ORANSlice/oai_ran/cmake_targets/ran_build/build

echo "╔══════════════════════════════════════════════════════════════════╗"
echo "║                    Démarrage gNB OAI                              ║"
echo "╚══════════════════════════════════════════════════════════════════╝"
echo ""
echo "Config: gnb.sa.band78.fr1.106PRB.usrpb210.conf"
echo "AMF: 127.0.0.1:38412"
echo ""

sudo ./nr-softmodem \
  -O $HOME/NexSlice/ORANSlice/oai_ran/targets/PROJECTS/GENERIC-NR-5GC/CONF/gnb.sa.band78.fr1.106PRB.usrpb210.conf \
  --rfsim \
  --sa
EOFGNB

chmod +x /tmp/start_gnb_oai.sh

# Script UE
cat > /tmp/start_ue_oai.sh <<'EOFUE'
#!/bin/bash
cd $HOME/NexSlice/ORANSlice/oai_ran/cmake_targets/ran_build/build

# Attendre 10 secondes que le gNB soit prêt
echo "⏱️  Attente du gNB (10 secondes)..."
sleep 10

echo "╔══════════════════════════════════════════════════════════════════╗"
echo "║                    Démarrage UE OAI                               ║"
echo "╚══════════════════════════════════════════════════════════════════╝"
echo ""
echo "IMSI: 208990000000001"
echo "DNN: oai"
echo ""

sudo ./nr-uesoftmodem \
  -C 3619200000 \
  -r 106 \
  --numerology 1 \
  --band 78 \
  --ssb 516 \
  --rfsim \
  -O /tmp/ue-simple.conf \
  --sa \
  --nokrnmod 1
EOFUE

chmod +x /tmp/start_ue_oai.sh

# Script test
cat > /tmp/test_connection.sh <<'EOFTEST'
#!/bin/bash

echo "╔══════════════════════════════════════════════════════════════════╗"
echo "║              Tests de Connectivité UE                            ║"
echo "╚══════════════════════════════════════════════════════════════════╝"
echo ""

# Attendre l'interface
echo "⏱️  Attente de l'interface oaitun_ue1 (30 secondes max)..."
for i in {1..30}; do
    if ip addr show oaitun_ue1 &>/dev/null; then
        echo "✓ Interface oaitun_ue1 détectée"
        break
    fi
    sleep 1
done

if ! ip addr show oaitun_ue1 &>/dev/null; then
    echo "✗ Interface oaitun_ue1 non créée après 30s"
    exit 1
fi

# Afficher l'IP
UE_IP=$(ip -4 addr show oaitun_ue1 | grep inet | awk '{print $2}' | cut -d'/' -f1)
echo "IP UE: $UE_IP"
echo ""

# Test ping
echo "🔍 Test 1: Ping Google DNS"
if ping -I oaitun_ue1 -c 3 8.8.8.8; then
    echo "✓ Connectivité Internet OK"
else
    echo "✗ Pas de connectivité Internet"
fi
echo ""

# Test iperf3 si serveur dispo
IPERF_IP=$(sudo k3s kubectl get svc -n nexslice iperf3-svc -o jsonpath='{.spec.clusterIP}' 2>/dev/null)
if [ -n "$IPERF_IP" ]; then
    echo "🔍 Test 2: iperf3 vers $IPERF_IP"
    iperf3 -c $IPERF_IP -p 5201 -t 10 -B $UE_IP || echo "✗ iperf3 échoué"
else
    echo "⚠️  Serveur iperf3 non trouvé, test skip"
fi

echo ""
echo "════════════════════════════════════════════════════════════════════"
EOFTEST

chmod +x /tmp/test_connection.sh

log_success "Scripts créés:"
log_success "  • /tmp/start_gnb_oai.sh"
log_success "  • /tmp/start_ue_oai.sh"
log_success "  • /tmp/test_connection.sh"
echo ""

# =============================================================================
# Instructions Finales
# =============================================================================

echo ""
echo "╔══════════════════════════════════════════════════════════════════╗"
echo "║                    Configuration Terminée ! 🎉                   ║"
echo "╚══════════════════════════════════════════════════════════════════╝"
echo ""

log_success "Tout est prêt ! Maintenant :"
echo ""
echo "📍 Terminal 1 - Démarrer le gNB :"
echo "   /tmp/start_gnb_oai.sh"
echo ""
echo "📍 Terminal 2 - Démarrer le UE (attendre que gNB soit up) :"
echo "   /tmp/start_ue_oai.sh"
echo ""
echo "📍 Terminal 3 - Tests (attendre 20-30s après démarrage UE) :"
echo "   /tmp/test_connection.sh"
echo ""

log_info "Logs attendus :"
echo "  gNB : [NGAP] Sending NG_SETUP_REQUEST"
echo "        [NGAP] Received NG_SETUP_RESPONSE ✅"
echo ""
echo "  UE :  [NR_RRC] State = NR_RRC_CONNECTED"
echo "        [NAS] Registration Accept ✅"
echo "        [NAS] PDU Session Establishment Accept ✅"
echo ""

log_warning "⚠️  Pour arrêter proprement :"
echo "   # Ctrl+C dans chaque terminal"
echo "   sudo pkill -9 nr-softmodem"
echo "   sudo pkill -9 nr-uesoftmodem"
echo "   kill $PF_PID  # Arrêter port-forward"
echo ""

echo "════════════════════════════════════════════════════════════════════"
echo ""
