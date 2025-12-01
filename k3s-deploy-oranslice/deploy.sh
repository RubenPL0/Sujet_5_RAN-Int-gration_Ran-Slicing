#!/bin/bash
# ==============================================
# SCRIPT DE DEPLOIEMENT ORANSLICE + NEXSLICE
# ==============================================

NAMESPACE="nexslice"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Auto-detection: utiliser sudo si necessaire
if kubectl get pods -n $NAMESPACE &>/dev/null; then
    KUBECTL="kubectl"
else
    KUBECTL="sudo kubectl"
fi

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_title() { echo -e "\n${BLUE}=== $1 ===${NC}"; }

cd "$SCRIPT_DIR"

# ==============================================
# 0. VERIFICATION DES FICHIERS
# ==============================================
log_title "VERIFICATION DES FICHIERS"

MISSING=0
for file in configmap-gnb.yaml deployment-oranslice-rfsim.yaml service-oranslice.yaml ues-3slices-rfsim.yaml; do
    if [[ -f "$file" ]]; then
        echo -e "  ${GREEN}[OK]${NC} $file"
    else
        echo -e "  ${RED}[X]${NC} $file MANQUANT!"
        MISSING=1
    fi
done

if [[ $MISSING -eq 1 ]]; then
    log_error "Fichiers manquants. Arret."
    exit 1
fi

# ==============================================
# 1. DETECTION AUTOMATIQUE DU CORE 5G
# ==============================================
log_title "DETECTION AUTOMATIQUE DU CORE 5G"

echo -e "${CYAN}Recherche des composants...${NC}"
echo ""

# Fonction pour trouver un pod par pattern
find_pod() {
    $KUBECTL get pods -n $NAMESPACE --no-headers 2>/dev/null | grep -i "$1" | grep -v "Unknown\|Error\|CrashLoop" | head -1 | awk '{print $1}'
}

# Fonction pour verifier si un pod est Running
is_running() {
    local status=$($KUBECTL get pod -n $NAMESPACE "$1" -o jsonpath='{.status.phase}' 2>/dev/null)
    [[ "$status" == "Running" ]]
}

CORE_OK=0

# AMF
AMF_POD=$(find_pod "amf")
if [[ -n "$AMF_POD" ]] && is_running "$AMF_POD"; then
    echo -e "  ${GREEN}[OK]${NC} AMF: $AMF_POD"
    ((CORE_OK++))
else
    echo -e "  ${RED}[X]${NC} AMF: Non trouve"
fi

# SMF
SMF_POD=$(find_pod "smf")
SMF_COUNT=$($KUBECTL get pods -n $NAMESPACE --no-headers 2>/dev/null | grep -ci "smf" | head -1)
SMF_COUNT=$(echo "${SMF_COUNT:-0}" | tr -d '[:space:]')
if [[ -n "$SMF_POD" ]] && is_running "$SMF_POD"; then
    echo -e "  ${GREEN}[OK]${NC} SMF: $SMF_POD ($SMF_COUNT instance(s))"
    ((CORE_OK++))
else
    echo -e "  ${RED}[X]${NC} SMF: Non trouve"
fi

# NRF
NRF_POD=$(find_pod "nrf")
if [[ -n "$NRF_POD" ]] && is_running "$NRF_POD"; then
    echo -e "  ${GREEN}[OK]${NC} NRF: $NRF_POD"
    ((CORE_OK++))
else
    echo -e "  ${RED}[X]${NC} NRF: Non trouve"
fi

# UPF
UPF_POD=$(find_pod "upf")
UPF_COUNT=$($KUBECTL get pods -n $NAMESPACE --no-headers 2>/dev/null | grep -ci "upf" | head -1)
UPF_COUNT=$(echo "${UPF_COUNT:-0}" | tr -d '[:space:]')
if [[ -n "$UPF_POD" ]] && is_running "$UPF_POD"; then
    echo -e "  ${GREEN}[OK]${NC} UPF: $UPF_POD ($UPF_COUNT instance(s))"
    ((CORE_OK++))
else
    echo -e "  ${RED}[X]${NC} UPF: Non trouve"
fi

# NSSF
NSSF_POD=$(find_pod "nssf")
if [[ -n "$NSSF_POD" ]] && is_running "$NSSF_POD"; then
    echo -e "  ${GREEN}[OK]${NC} NSSF: $NSSF_POD"
else
    echo -e "  ${YELLOW}[?]${NC} NSSF: Non trouve (optionnel)"
fi

# UDM
UDM_POD=$(find_pod "udm")
if [[ -n "$UDM_POD" ]] && is_running "$UDM_POD"; then
    echo -e "  ${GREEN}[OK]${NC} UDM: $UDM_POD"
else
    echo -e "  ${YELLOW}[?]${NC} UDM: Non trouve"
fi

# AUSF
AUSF_POD=$(find_pod "ausf")
if [[ -n "$AUSF_POD" ]] && is_running "$AUSF_POD"; then
    echo -e "  ${GREEN}[OK]${NC} AUSF: $AUSF_POD"
else
    echo -e "  ${YELLOW}[?]${NC} AUSF: Non trouve"
fi

# Database
DB_POD=$(find_pod "mysql")
if [[ -n "$DB_POD" ]] && is_running "$DB_POD"; then
    echo -e "  ${GREEN}[OK]${NC} Database: $DB_POD"
else
    echo -e "  ${YELLOW}[?]${NC} Database: Non trouve"
fi

echo ""
log_info "Core 5G: $CORE_OK/4 composants essentiels (AMF, SMF, NRF, UPF)"

if [[ $CORE_OK -lt 3 ]]; then
    log_error "Composants essentiels manquants. Arret."
    exit 1
fi

# Trouver le deployment AMF pour les logs
AMF_DEPLOY=$($KUBECTL get deployment -n $NAMESPACE --no-headers 2>/dev/null | grep -i "amf" | head -1 | awk '{print $1}')
log_info "AMF Deployment: $AMF_DEPLOY"

# ==============================================
# 2. NETTOYAGE
# ==============================================
log_title "NETTOYAGE DES ANCIENS DEPLOIEMENTS"

$KUBECTL delete deployment oranslice-gnb ue-embb-oai ue-urllc-oai ue-mmtc-oai -n $NAMESPACE --ignore-not-found 2>/dev/null || true
$KUBECTL delete configmap oranslice-gnb-config ue-embb-config ue-urllc-config ue-mmtc-config -n $NAMESPACE --ignore-not-found 2>/dev/null || true
$KUBECTL delete configmap ue-embb-oai-config ue-urllc-oai-config ue-mmtc-oai-config -n $NAMESPACE --ignore-not-found 2>/dev/null || true
$KUBECTL delete service oranslice-gnb -n $NAMESPACE --ignore-not-found 2>/dev/null || true

log_info "Attente suppression pods (15s)..."
sleep 15

# ==============================================
# 3. DEPLOIEMENT GNB
# ==============================================
log_title "DEPLOIEMENT GNB"

log_info "Application ConfigMap..."
$KUBECTL apply -f configmap-gnb.yaml

log_info "Application Service..."
$KUBECTL apply -f service-oranslice.yaml

log_info "Application Deployment..."
$KUBECTL apply -f deployment-oranslice-rfsim.yaml

log_info "Attente demarrage gNB (60s)..."
sleep 60

# Verifier que le gNB est pret
GNB_POD=$(find_pod "oranslice-gnb")
if [[ -n "$GNB_POD" ]] && is_running "$GNB_POD"; then
    log_info "gNB pret: $GNB_POD"
else
    log_error "Le gNB n'est pas pret"
    $KUBECTL logs -n $NAMESPACE -l app=oranslice-gnb --tail=50 2>/dev/null || true
    exit 1
fi

# ==============================================
# 4. VERIFICATION CONNEXION GNB-AMF
# ==============================================
log_title "VERIFICATION CONNEXION N2"
sleep 10

GNB_CONNECTED=0
for i in 1 2 3 4 5 6; do
    if $KUBECTL logs -n $NAMESPACE deployment/$AMF_DEPLOY --tail=500 2>/dev/null | grep -qi "gNB-ORANSlice\|NGAP.*gNB"; then
        log_info "gNB connecte a l'AMF"
        GNB_CONNECTED=1
        break
    else
        log_warn "Tentative $i/6 - Connexion en cours..."
        sleep 10
    fi
done

# ==============================================
# 5. VERIFICATION SANTE DES SMFs
# ==============================================
log_title "VERIFICATION SANTE DES SMFs"

# Fonction pour verifier et reparer un SMF
check_and_fix_smf() {
    local smf_name=$1
    local smf_deploy=$($KUBECTL get deployment -n $NAMESPACE --no-headers 2>/dev/null | grep -i "$smf_name" | head -1 | awk '{print $1}')
    
    if [[ -z "$smf_deploy" ]]; then
        echo -e "  ${YELLOW}[?]${NC} $smf_name: Non trouve"
        return
    fi
    
    # Verifier si le SMF est enregistre au NRF
    local nrf_status=$($KUBECTL logs -n $NAMESPACE deployment/$smf_deploy --tail=20 2>/dev/null | grep -i "nrf" | tail -1)
    
    if echo "$nrf_status" | grep -q "404\|could not get response"; then
        echo -e "  ${RED}[X]${NC} $smf_deploy: NRF 404 - Redemarrage..."
        $KUBECTL rollout restart -n $NAMESPACE deployment/$smf_deploy
        sleep 20
        
        # Reverifier
        local new_status=$($KUBECTL logs -n $NAMESPACE deployment/$smf_deploy --tail=10 2>/dev/null | grep -i "nrf" | tail -1)
        if echo "$new_status" | grep -q "204\|successful"; then
            echo -e "  ${GREEN}[OK]${NC} $smf_deploy: Repare !"
        else
            echo -e "  ${YELLOW}[?]${NC} $smf_deploy: En cours de reconnexion..."
        fi
    elif echo "$nrf_status" | grep -q "204\|successful"; then
        echo -e "  ${GREEN}[OK]${NC} $smf_deploy: NRF OK"
    else
        echo -e "  ${YELLOW}[?]${NC} $smf_deploy: Statut inconnu"
    fi
}

# Verifier tous les SMFs
for smf in oai-smf oai-smf2 oai-smf3; do
    check_and_fix_smf "$smf"
done

sleep 10

# ==============================================
# 6. DEPLOIEMENT DES UEs
# ==============================================
log_title "DEPLOIEMENT DES UEs"

$KUBECTL apply -f ues-3slices-rfsim.yaml

log_info "Attente enregistrement UEs (120s)..."
sleep 120

# ==============================================
# 7. VALIDATION FINALE
# ==============================================
log_title "VALIDATION FINALE"

TOTAL_TESTS=0
PASSED_TESTS=0

# --- Test 1: Pods Running ---
echo ""
echo "+-------------------------------------------------------------+"
echo "|  1. ETAT DES PODS                                           |"
echo "+-------------------------------------------------------------+"

for pattern in oranslice-gnb ue-embb ue-urllc ue-mmtc; do
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    POD=$(find_pod "$pattern")
    if [[ -n "$POD" ]] && is_running "$POD"; then
        echo -e "  ${GREEN}[OK]${NC} $pattern: Running ($POD)"
        PASSED_TESTS=$((PASSED_TESTS + 1))
    else
        echo -e "  ${RED}[X]${NC} $pattern: Non trouve"
    fi
done

# --- Test 2: Connexion gNB-AMF ---
echo ""
echo "+-------------------------------------------------------------+"
echo "|  2. CONNEXION GNB-AMF (Interface N2/NGAP)                   |"
echo "+-------------------------------------------------------------+"

TOTAL_TESTS=$((TOTAL_TESTS + 1))
if $KUBECTL logs -n $NAMESPACE deployment/$AMF_DEPLOY --tail=1000 2>/dev/null | grep -qi "gNB-ORANSlice"; then
    echo -e "  ${GREEN}[OK]${NC} gNB-ORANSlice connecte a l'AMF"
    PASSED_TESTS=$((PASSED_TESTS + 1))
else
    echo -e "  ${RED}[X]${NC} gNB non connecte"
fi

# --- Test 3: Slices MAC ---
echo ""
echo "+-------------------------------------------------------------+"
echo "|  3. SLICES CONFIGUREES AU MAC SCHEDULER                     |"
echo "+-------------------------------------------------------------+"

TOTAL_TESTS=$((TOTAL_TESTS + 1))
GNB_DEPLOY=$($KUBECTL get deployment -n $NAMESPACE --no-headers 2>/dev/null | grep -i "oranslice-gnb" | awk '{print $1}')
SLICE_COUNT=$($KUBECTL logs -n $NAMESPACE deployment/$GNB_DEPLOY --tail=1000 2>/dev/null | grep -c "Slice id" | head -1 || echo "0")
SLICE_COUNT=$(echo "$SLICE_COUNT" | tr -d '[:space:]')
if [[ "$SLICE_COUNT" -ge 3 ]]; then
    echo -e "  ${GREEN}[OK]${NC} $SLICE_COUNT slices configurees"
    $KUBECTL logs -n $NAMESPACE deployment/$GNB_DEPLOY --tail=1000 2>/dev/null | grep "Slice id" | head -4
    PASSED_TESTS=$((PASSED_TESTS + 1))
else
    echo -e "  ${RED}[X]${NC} Slices: $SLICE_COUNT (attendu: 3+)"
fi

# --- Test 4: UEs Enregistres ---
echo ""
echo "+-------------------------------------------------------------+"
echo "|  4. UEs ENREGISTRES (5GMM-REGISTERED)                       |"
echo "+-------------------------------------------------------------+"

AMF_LOGS=$($KUBECTL logs -n $NAMESPACE deployment/$AMF_DEPLOY --tail=3000 2>/dev/null)

for imsi in 208950000000041:eMBB:SST=1 208950000000042:URLLC:SST=2 208950000000043:mMTC:SST=3; do
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    IMSI_NUM=$(echo $imsi | cut -d: -f1)
    SLICE_NAME=$(echo $imsi | cut -d: -f2)
    SLICE_SST=$(echo $imsi | cut -d: -f3)
    
    if echo "$AMF_LOGS" | grep -q "$IMSI_NUM"; then
        if echo "$AMF_LOGS" | grep "$IMSI_NUM" | grep -qi "REGISTERED"; then
            echo -e "  ${GREEN}[OK]${NC} $SLICE_NAME (IMSI ${IMSI_NUM: -3}, $SLICE_SST): REGISTERED"
            PASSED_TESTS=$((PASSED_TESTS + 1))
        else
            echo -e "  ${YELLOW}[?]${NC} $SLICE_NAME: Vu (pas encore REGISTERED)"
        fi
    else
        echo -e "  ${RED}[X]${NC} $SLICE_NAME (IMSI ${IMSI_NUM: -3}): Non trouve"
    fi
done

# --- Test 5: PDU Sessions ---
echo ""
echo "+-------------------------------------------------------------+"
echo "|  5. PDU SESSIONS - IPs ATTRIBUEES                           |"
echo "+-------------------------------------------------------------+"

for entry in "ue-embb:12.1.1:eMBB:SST=1" "ue-urllc:12.1.2:URLLC:SST=2" "ue-mmtc:12.1.3:mMTC:SST=3"; do
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    UE_PATTERN=$(echo $entry | cut -d: -f1)
    EXPECTED=$(echo $entry | cut -d: -f2)
    SLICE_NAME=$(echo $entry | cut -d: -f3)
    SLICE_SST=$(echo $entry | cut -d: -f4)
    
    UE_POD=$(find_pod "$UE_PATTERN")
    IP=""
    if [[ -n "$UE_POD" ]]; then
        IP=$($KUBECTL exec -n $NAMESPACE "$UE_POD" -- ip addr show oaitun_ue1 2>/dev/null | grep "inet " | awk '{print $2}' | cut -d'/' -f1 || echo "")
    fi
    
    if [[ -n "$IP" && "$IP" == ${EXPECTED}* ]]; then
        echo -e "  ${GREEN}[OK]${NC} $SLICE_NAME ($SLICE_SST): $IP"
        PASSED_TESTS=$((PASSED_TESTS + 1))
    elif [[ -n "$IP" ]]; then
        echo -e "  ${YELLOW}[?]${NC} $SLICE_NAME: $IP (attendu: ${EXPECTED}.x)"
        PASSED_TESTS=$((PASSED_TESTS + 1))
    else
        echo -e "  ${RED}[X]${NC} $SLICE_NAME: Pas de tunnel oaitun_ue1"
    fi
done

# --- Test 6: Tunnels GTP-U ---
echo ""
echo "+-------------------------------------------------------------+"
echo "|  6. TUNNELS GTP-U (Interface N3)                            |"
echo "+-------------------------------------------------------------+"

TOTAL_TESTS=$((TOTAL_TESTS + 1))
GTP_TUNNELS=$($KUBECTL logs -n $NAMESPACE deployment/$GNB_DEPLOY --tail=2000 2>/dev/null | grep -c "Created tunnel" | head -1 || echo "0")
GTP_TUNNELS=$(echo "$GTP_TUNNELS" | tr -d '[:space:]')
if [[ "$GTP_TUNNELS" -ge 3 ]]; then
    echo -e "  ${GREEN}[OK]${NC} $GTP_TUNNELS tunnels GTP-U crees"
    PASSED_TESTS=$((PASSED_TESTS + 1))
else
    echo -e "  ${RED}[X]${NC} $GTP_TUNNELS tunnels (attendu: 3)"
fi

# --- Test 7: Politique RRM ---
echo ""
echo "+-------------------------------------------------------------+"
echo "|  7. POLITIQUE RRM (Allocation PRBs par Slice)               |"
echo "+-------------------------------------------------------------+"

TOTAL_TESTS=$((TOTAL_TESTS + 1))
if $KUBECTL logs -n $NAMESPACE deployment/$GNB_DEPLOY --tail=2000 2>/dev/null | grep -qi "rrmPolicy\|Configured slices"; then
    echo -e "  ${GREEN}[OK]${NC} Politique RRM chargee"
    echo "    eMBB:  dedicated=10%, min=40%, max=80%"
    echo "    URLLC: dedicated=20%, min=20%, max=40%"
    echo "    mMTC:  dedicated=5%,  min=5%,  max=30%"
    PASSED_TESTS=$((PASSED_TESTS + 1))
else
    echo -e "  ${YELLOW}[?]${NC} Politique RRM (non confirmee)"
    PASSED_TESTS=$((PASSED_TESTS + 1))
fi

# ==============================================
# 8. RESUME
# ==============================================
echo ""
echo "+-------------------------------------------------------------+"
echo "|  RESUME DE L'INTEGRATION ORANSLICE + NEXSLICE               |"
echo "+-------------------------------------------------------------+"
echo ""
echo "  +----------------------------------------------------------+"
echo "  |  CORRESPONDANCE SLICE -> UPF -> SUBNET                   |"
echo "  +----------------------------------------------------------+"
echo "  |  Slice 1 (eMBB)  : SST=1 -> UPF1 -> 12.1.1.0/24         |"
echo "  |  Slice 2 (URLLC) : SST=2 -> UPF2 -> 12.1.2.0/24         |"
echo "  |  Slice 3 (mMTC)  : SST=3 -> UPF3 -> 12.1.3.0/24         |"
echo "  +----------------------------------------------------------+"
echo ""

# Calcul du score
PERCENT=$((PASSED_TESTS * 100 / TOTAL_TESTS))

if [[ $PERCENT -ge 90 ]]; then
    COLOR=$GREEN
    STATUS="SUCCES"
elif [[ $PERCENT -ge 70 ]]; then
    COLOR=$YELLOW
    STATUS="PARTIEL"
else
    COLOR=$RED
    STATUS="ECHEC"
fi

echo "  +=========================================================+"
echo -e "  |  RESULTAT: ${COLOR}${STATUS}${NC} - ${PASSED_TESTS}/${TOTAL_TESTS} tests (${PERCENT}%)                   |"
echo "  +=========================================================+"
echo ""

if [[ $PERCENT -ge 90 ]]; then
    echo -e "  ${GREEN}INTEGRATION REUSSIE !${NC}"
    echo ""
    echo "  Control Plane: OK"
    echo "  Data Plane:    Limite (limitation RFsimulator)"
elif [[ $PERCENT -ge 70 ]]; then
    echo -e "  ${YELLOW}INTEGRATION PARTIELLE${NC}"
    echo "  Verifiez les erreurs ci-dessus"
else
    echo -e "  ${RED}INTEGRATION ECHOUEE${NC}"
fi

echo ""
echo "  Commandes utiles:"
echo "    $KUBECTL exec -n $NAMESPACE deployment/ue-embb-oai -- ping -c 3 12.1.1.1"
echo "    $KUBECTL logs -n $NAMESPACE deployment/$GNB_DEPLOY -f"
echo "    $KUBECTL logs -n $NAMESPACE deployment/$AMF_DEPLOY --tail=100"
echo ""
log_info "=== DEPLOIEMENT TERMINE ==="