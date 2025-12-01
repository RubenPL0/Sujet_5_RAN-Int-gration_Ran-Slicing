#!/bin/bash
# ==============================================
# HEALTH CHECK & AUTO-REPAIR - NexSlice + ORANSlice
# Usage: ./healthcheck.sh [--fix]
# ==============================================

NAMESPACE="nexslice"
AUTO_FIX=0

if [[ "$1" == "--fix" ]]; then
    AUTO_FIX=1
fi

# Auto-detection sudo
if kubectl get pods -n $NAMESPACE &>/dev/null; then
    KUBECTL="kubectl"
else
    KUBECTL="sudo kubectl"
fi

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=== HEALTH CHECK NexSlice + ORANSlice ===${NC}"
echo ""

ISSUES=0

# ==============================================
# 1. VERIFIER LES SMFs (enregistrement NRF)
# ==============================================
echo -e "${BLUE}[1/4] SMFs - Enregistrement NRF${NC}"

for smf in oai-smf oai-smf2 oai-smf3; do
    smf_deploy=$($KUBECTL get deployment -n $NAMESPACE --no-headers 2>/dev/null | grep -i "^$smf" | awk '{print $1}')
    
    if [[ -z "$smf_deploy" ]]; then
        continue
    fi
    
    nrf_log=$($KUBECTL logs -n $NAMESPACE deployment/$smf_deploy --tail=30 2>/dev/null | grep -i "nrf" | tail -3)
    
    if echo "$nrf_log" | grep -q "404\|could not get response"; then
        echo -e "  ${RED}[X]${NC} $smf_deploy: NRF deconnecte (404)"
        ISSUES=$((ISSUES + 1))
        
        if [[ $AUTO_FIX -eq 1 ]]; then
            echo -e "    -> Redemarrage..."
            $KUBECTL rollout restart -n $NAMESPACE deployment/$smf_deploy
            sleep 25
            new_log=$($KUBECTL logs -n $NAMESPACE deployment/$smf_deploy --tail=10 2>/dev/null | grep -i "nrf" | tail -1)
            if echo "$new_log" | grep -q "204\|successful"; then
                echo -e "    ${GREEN}[OK] Repare !${NC}"
                ISSUES=$((ISSUES - 1))
            fi
        fi
    elif echo "$nrf_log" | grep -q "204\|successful"; then
        echo -e "  ${GREEN}[OK]${NC} $smf_deploy: NRF OK"
    else
        echo -e "  ${YELLOW}[?]${NC} $smf_deploy: Statut inconnu"
    fi
done

# ==============================================
# 2. VERIFIER LE GNB (connexion AMF)
# ==============================================
echo ""
echo -e "${BLUE}[2/4] gNB - Connexion AMF (N2/NGAP)${NC}"

gnb_deploy=$($KUBECTL get deployment -n $NAMESPACE --no-headers 2>/dev/null | grep -i "oranslice-gnb\|oai-gnb" | head -1 | awk '{print $1}')
amf_deploy=$($KUBECTL get deployment -n $NAMESPACE --no-headers 2>/dev/null | grep -i "amf" | head -1 | awk '{print $1}')

if [[ -n "$gnb_deploy" && -n "$amf_deploy" ]]; then
    amf_log=$($KUBECTL logs -n $NAMESPACE deployment/$amf_deploy --tail=100 2>/dev/null)
    
    if echo "$amf_log" | grep -qi "gNB.*Connected\|gNB-ORANSlice"; then
        echo -e "  ${GREEN}[OK]${NC} gNB connecte a l'AMF"
    else
        echo -e "  ${RED}[X]${NC} gNB non connecte"
        ISSUES=$((ISSUES + 1))
        
        if [[ $AUTO_FIX -eq 1 ]]; then
            echo -e "    -> Redemarrage gNB..."
            $KUBECTL rollout restart -n $NAMESPACE deployment/$gnb_deploy
            sleep 60
        fi
    fi
    
    # Verifier erreurs SCTP
    sctp_errors=$($KUBECTL logs -n $NAMESPACE deployment/$amf_deploy --tail=50 2>/dev/null | grep -c "sctp.*error\|Invalid argument" || echo "0")
    sctp_errors=$(echo "$sctp_errors" | tr -d '[:space:]')
    
    if [[ "$sctp_errors" -gt 5 ]]; then
        echo -e "  ${RED}[X]${NC} Erreurs SCTP detectees ($sctp_errors)"
        ISSUES=$((ISSUES + 1))
        
        if [[ $AUTO_FIX -eq 1 ]]; then
            echo -e "    -> Redemarrage AMF + gNB..."
            $KUBECTL rollout restart -n $NAMESPACE deployment/$amf_deploy
            sleep 30
            $KUBECTL rollout restart -n $NAMESPACE deployment/$gnb_deploy
            sleep 60
        fi
    else
        echo -e "  ${GREEN}[OK]${NC} SCTP OK (pas d'erreurs recentes)"
    fi
else
    echo -e "  ${YELLOW}[?]${NC} gNB ou AMF non trouve"
fi

# ==============================================
# 3. VERIFIER LES UEs (PDU Sessions)
# ==============================================
echo ""
echo -e "${BLUE}[3/4] UEs - PDU Sessions${NC}"

for ue_info in "ue-embb:12.1.1:eMBB:SST=1" "ue-urllc:12.1.2:URLLC:SST=2" "ue-mmtc:12.1.3:mMTC:SST=3"; do
    ue_pattern=$(echo $ue_info | cut -d: -f1)
    expected=$(echo $ue_info | cut -d: -f2)
    slice_name=$(echo $ue_info | cut -d: -f3)
    
    ue_pod=$($KUBECTL get pods -n $NAMESPACE --no-headers 2>/dev/null | grep -i "$ue_pattern" | grep -v "Unknown\|Error" | head -1 | awk '{print $1}')
    
    if [[ -z "$ue_pod" ]]; then
        echo -e "  ${YELLOW}[?]${NC} $slice_name: Pod non trouve"
        continue
    fi
    
    ip=$($KUBECTL exec -n $NAMESPACE "$ue_pod" -- ip addr show oaitun_ue1 2>/dev/null | grep "inet " | awk '{print $2}' | cut -d'/' -f1 || echo "")
    
    if [[ -n "$ip" && "$ip" == ${expected}* ]]; then
        echo -e "  ${GREEN}[OK]${NC} $slice_name: $ip"
    elif [[ -n "$ip" ]]; then
        echo -e "  ${YELLOW}[?]${NC} $slice_name: $ip (attendu ${expected}.x)"
    else
        echo -e "  ${RED}[X]${NC} $slice_name: Pas de tunnel"
        ISSUES=$((ISSUES + 1))
        
        if [[ $AUTO_FIX -eq 1 ]]; then
            ue_deploy=$($KUBECTL get deployment -n $NAMESPACE --no-headers 2>/dev/null | grep -i "$ue_pattern" | head -1 | awk '{print $1}')
            if [[ -n "$ue_deploy" ]]; then
                echo -e "    -> Redemarrage $ue_deploy..."
                $KUBECTL rollout restart -n $NAMESPACE deployment/$ue_deploy
            fi
        fi
    fi
done

# ==============================================
# 4. VERIFIER LES PODS EN ERREUR
# ==============================================
echo ""
echo -e "${BLUE}[4/4] Pods en erreur${NC}"

error_pods=$($KUBECTL get pods -n $NAMESPACE --no-headers 2>/dev/null | grep -E "CrashLoop|Error|ImagePull" | awk '{print $1}')

if [[ -z "$error_pods" ]]; then
    echo -e "  ${GREEN}[OK]${NC} Aucun pod en erreur"
else
    for pod in $error_pods; do
        echo -e "  ${RED}[X]${NC} $pod"
        ISSUES=$((ISSUES + 1))
    done
fi

# ==============================================
# RESUME
# ==============================================
echo ""
echo "=========================================="

if [[ $ISSUES -eq 0 ]]; then
    echo -e "${GREEN}[OK] Tout est OK !${NC}"
else
    echo -e "${RED}[ERREUR] $ISSUES probleme(s) detecte(s)${NC}"
    if [[ $AUTO_FIX -eq 0 ]]; then
        echo ""
        echo "Relancer avec --fix pour tenter une reparation automatique :"
        echo "  ./healthcheck.sh --fix"
    fi
fi

echo ""
exit $ISSUES