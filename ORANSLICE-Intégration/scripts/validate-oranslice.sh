#!/bin/bash
echo "=============================================="
echo "  VALIDATION INTEGRATION ORANSLICE + NEXSLICE"
echo "  $(date)"
echo "=============================================="

echo ""
echo "----------------------------------------------"
echo "  1. ORANSLICE GNB - ETAT DU POD"
echo "----------------------------------------------"
sudo k3s kubectl get pods -n nexslice -l app=oranslice-gnb -o wide

echo ""
echo "----------------------------------------------"
echo "  2. ORANSLICE GNB - VERSION ET IMAGE"
echo "----------------------------------------------"
sudo k3s kubectl get pods -n nexslice -l app=oranslice-gnb -o jsonpath='{.items[0].spec.containers[0].image}'
echo ""

echo ""
echo "----------------------------------------------"
echo "  3. SDAP LAYER (Data Plane)"
echo "----------------------------------------------"
sudo k3s kubectl logs -n nexslice deployment/oranslice-gnb 2>&1 | grep -i "sdap" | tail -3

echo ""
echo "----------------------------------------------"
echo "  4. CONFIGURATION DES SLICES AU MAC SCHEDULER"
echo "----------------------------------------------"
sudo k3s kubectl logs -n nexslice deployment/oranslice-gnb 2>&1 | grep -E "Configured slices|Slice id" | head -6

echo ""
echo "----------------------------------------------"
echo "  5. POLITIQUE RRM (rrmPolicy.json)"
echo "----------------------------------------------"
sudo k3s kubectl get configmap -n nexslice oranslice-gnb-config -o jsonpath='{.data.rrmPolicy\.json}' 2>/dev/null | head -20
echo ""

echo ""
echo "----------------------------------------------"
echo "  6. CONNEXION GNB - AMF (Interface N2/NGAP)"
echo "----------------------------------------------"
echo "IP AMF : $(sudo k3s kubectl get pod -n nexslice -l app.kubernetes.io/name=oai-amf -o jsonpath='{.items[0].status.podIP}')"
echo "Service AMF : $(sudo k3s kubectl get svc -n nexslice oai-amf -o jsonpath='{.spec.clusterIP}')"
echo ""
echo "Cote gNB :"
sudo k3s kubectl logs -n nexslice deployment/oranslice-gnb 2>&1 | grep -E "NGAP_REGISTER_GNB_CNF|associated AMF" | tail -3
echo ""
echo "Cote AMF :"
sudo k3s kubectl logs -n nexslice deployment/oai-amf 2>&1 | grep -E "gNB-ORANSlice|Connected.*0x1E" | tail -3

echo ""
echo "----------------------------------------------"
echo "  7. COMPOSANTS CORE 5G - IPs"
echo "----------------------------------------------"
echo "AMF  : $(sudo k3s kubectl get pod -n nexslice -l app.kubernetes.io/name=oai-amf -o jsonpath='{.items[0].status.podIP}')"
echo "SMF  : $(sudo k3s kubectl get pod -n nexslice -l app.kubernetes.io/name=oai-smf -o jsonpath='{.items[0].status.podIP}')"
echo "NRF  : $(sudo k3s kubectl get pod -n nexslice -l app.kubernetes.io/name=oai-nrf -o jsonpath='{.items[0].status.podIP}')"
echo "NSSF : $(sudo k3s kubectl get pod -n nexslice -l app.kubernetes.io/name=oai-nssf -o jsonpath='{.items[0].status.podIP}')"
echo "UDM  : $(sudo k3s kubectl get pod -n nexslice -l app.kubernetes.io/name=oai-udm -o jsonpath='{.items[0].status.podIP}')"
echo "UDR  : $(sudo k3s kubectl get pod -n nexslice -l app.kubernetes.io/name=oai-udr -o jsonpath='{.items[0].status.podIP}')"
echo "AUSF : $(sudo k3s kubectl get pod -n nexslice -l app.kubernetes.io/name=oai-ausf -o jsonpath='{.items[0].status.podIP}')"

echo ""
echo "----------------------------------------------"
echo "  8. UEs ENREGISTRES (5GMM-REGISTERED)"
echo "----------------------------------------------"
sudo k3s kubectl logs -n nexslice deployment/oai-amf 2>&1 | grep "5GMM-REGISTERED" | tail -5

echo ""
echo "----------------------------------------------"
echo "  9. TUNNELS GTP-U CREES (Interface N3)"
echo "----------------------------------------------"
sudo k3s kubectl logs -n nexslice deployment/oranslice-gnb 2>&1 | grep "Created tunnel" | tail -5

echo ""
echo "----------------------------------------------"
echo "  10. PDU SESSIONS - IPs ATTRIBUEES AUX UEs"
echo "----------------------------------------------"
echo "UE eMBB (IMSI 041, SST=1, DNN=oai) :"
sudo k3s kubectl exec -n nexslice deployment/ue-embb-oai -- ip addr show oaitun_ue1 2>&1 | grep "inet " || echo "  [Pas d interface]"
echo ""
echo "UE URLLC (IMSI 042, SST=2, DNN=oai2) :"
sudo k3s kubectl exec -n nexslice deployment/ue-urllc-oai -- ip addr show oaitun_ue1 2>&1 | grep "inet " || echo "  [Pas d interface]"
echo ""
echo "UE mMTC (IMSI 043, SST=3, DNN=oai3) :"
sudo k3s kubectl exec -n nexslice deployment/ue-mmtc-oai -- ip addr show oaitun_ue1 2>&1 | grep "inet " || echo "  [Pas d interface]"

echo ""
echo "----------------------------------------------"
echo "  11. CORRESPONDANCE SLICE - UPF - SUBNET"
echo "----------------------------------------------"
echo "Slice 1 (eMBB)  : SST=1 -> UPF1 ($(sudo k3s kubectl get pod -n nexslice -l app.kubernetes.io/name=oai-upf -o jsonpath='{.items[0].status.podIP}')) -> 12.1.1.0/24"
echo "Slice 2 (URLLC) : SST=2 -> UPF2 ($(sudo k3s kubectl get pod -n nexslice -l app.kubernetes.io/name=oai-upf2 -o jsonpath='{.items[0].status.podIP}')) -> 12.1.2.0/24"
echo "Slice 3 (mMTC)  : SST=3 -> UPF3 ($(sudo k3s kubectl get pod -n nexslice -l app.kubernetes.io/name=oai-upf3 -o jsonpath='{.items[0].status.podIP}')) -> 12.1.3.0/24"

echo ""
echo "----------------------------------------------"
echo "  12. ETAT DES PODS PRINCIPAUX"
echo "----------------------------------------------"
sudo k3s kubectl get pods -n nexslice | grep -E "NAME|gnb|amf|smf|upf|ue-|nrf|nssf"

echo ""
echo "----------------------------------------------"
echo "  13. CONFIGURATION GNB (enable_sdap, slices)"
echo "----------------------------------------------"
sudo k3s kubectl get configmap -n nexslice oranslice-gnb-config -o jsonpath='{.data.gnb\.conf}' 2>/dev/null | grep -E "enable_sdap|gNB_name|snssaiList|sst" | head -15
echo ""

echo ""
echo "----------------------------------------------"
echo "  14. SUBSCRIBERS EN BASE DE DONNEES"
echo "----------------------------------------------"
MYSQL_POD=$(sudo k3s kubectl get pods -n nexslice -l app.kubernetes.io/name=mysql -o jsonpath='{.items[0].metadata.name}')
echo "UEs dans AuthenticationSubscription :"
sudo k3s kubectl exec -n nexslice $MYSQL_POD -- mysql -utest -ptest -e "SELECT ueid FROM oai_db.AuthenticationSubscription WHERE ueid LIKE '2089500000000%';" 2>/dev/null | tail -5
echo ""
echo "Sessions dans SessionManagementSubscriptionData :"
sudo k3s kubectl exec -n nexslice $MYSQL_POD -- mysql -utest -ptest -e "SELECT ueid, servingPlmnid, singleNssai FROM oai_db.SessionManagementSubscriptionData WHERE ueid LIKE '2089500000000%';" 2>/dev/null | tail -5

echo ""
echo "=============================================="
echo "  RESUME DE L INTEGRATION"
echo "=============================================="
echo ""

# Verification des elements
GNB_OK=$(sudo k3s kubectl get pods -n nexslice -l app=oranslice-gnb -o jsonpath='{.items[0].status.phase}')
GNB_IP=$(sudo k3s kubectl get pods -n nexslice -l app=oranslice-gnb -o jsonpath='{.items[0].status.podIP}')
AMF_IP=$(sudo k3s kubectl get pod -n nexslice -l app.kubernetes.io/name=oai-amf -o jsonpath='{.items[0].status.podIP}')
SDAP_OK=$(sudo k3s kubectl logs -n nexslice deployment/oranslice-gnb 2>&1 | grep -c "SDAP layer is enabled")
SLICES_OK=$(sudo k3s kubectl logs -n nexslice deployment/oranslice-gnb 2>&1 | grep "Slice id" | grep -c "sst = ")
GNB_AMF=$(sudo k3s kubectl logs -n nexslice deployment/oai-amf 2>&1 | grep -c "gNB-ORANSlice")
UE1=$(sudo k3s kubectl logs -n nexslice deployment/oai-amf 2>&1 | grep "5GMM-REGISTERED" | grep -c "208950000000041")
UE2=$(sudo k3s kubectl logs -n nexslice deployment/oai-amf 2>&1 | grep "5GMM-REGISTERED" | grep -c "208950000000042")
UE3=$(sudo k3s kubectl logs -n nexslice deployment/oai-amf 2>&1 | grep "5GMM-REGISTERED" | grep -c "208950000000043")
TUNNELS=$(sudo k3s kubectl logs -n nexslice deployment/oranslice-gnb 2>&1 | grep -c "Created tunnel")
IP1=$(sudo k3s kubectl exec -n nexslice deployment/ue-embb-oai -- ip addr show oaitun_ue1 2>&1 | grep -c "inet ")
IP2=$(sudo k3s kubectl exec -n nexslice deployment/ue-urllc-oai -- ip addr show oaitun_ue1 2>&1 | grep -c "inet ")
IP3=$(sudo k3s kubectl exec -n nexslice deployment/ue-mmtc-oai -- ip addr show oaitun_ue1 2>&1 | grep -c "inet ")

echo "Infrastructure :"
echo "  - ORANSlice gNB IP              : $GNB_IP"
echo "  - AMF IP                        : $AMF_IP"
echo ""
echo "Control Plane :"
echo "  - ORANSlice gNB running         : $([ "$GNB_OK" = "Running" ] && echo "OUI" || echo "NON")"
echo "  - SDAP layer active             : $([ $SDAP_OK -gt 0 ] && echo "OUI" || echo "NON")"
echo "  - Slices configurees au MAC     : $SLICES_OK / 3"
echo "  - Connexion gNB-AMF (N2)        : $([ $GNB_AMF -gt 0 ] && echo "OUI" || echo "NON")"
echo "  - UE eMBB enregistre (IMSI 041) : $([ $UE1 -gt 0 ] && echo "OUI" || echo "NON")"
echo "  - UE URLLC enregistre (IMSI 042): $([ $UE2 -gt 0 ] && echo "OUI" || echo "NON")"
echo "  - UE mMTC enregistre (IMSI 043) : $([ $UE3 -gt 0 ] && echo "OUI" || echo "NON")"
echo "  - Tunnels GTP-U crees           : $TUNNELS"
echo ""
echo "Data Plane :"
echo "  - PDU Session UE eMBB (IP)      : $([ $IP1 -gt 0 ] && echo "OUI (12.1.1.x)" || echo "NON")"
echo "  - PDU Session UE URLLC (IP)     : $([ $IP2 -gt 0 ] && echo "OUI (12.1.2.x)" || echo "NON")"
echo "  - PDU Session UE mMTC (IP)      : $([ $IP3 -gt 0 ] && echo "OUI (12.1.3.x)" || echo "NON")"
echo ""
echo "Limitation connue :"
echo "  - Ping vers gateway ne fonctionne pas (bug ORANSlice/RFsimulator)"
echo ""
echo "=============================================="
echo "  FIN DE LA VALIDATION"
echo "=============================================="
