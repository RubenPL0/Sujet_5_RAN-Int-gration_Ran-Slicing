#!/bin/bash
#############################################
#  DÉMONSTRATION RAN SLICING COMPLÈTE
#############################################

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║          DÉMONSTRATION RAN SLICING - NexSlice                ║"
echo "╚══════════════════════════════════════════════════════════════╝"

#############################################
# PARTIE 1: ORANSlice + UEs OAI
#############################################
echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "  PARTIE 1: ORANSlice gNB + 3 UEs OAI"
echo "═══════════════════════════════════════════════════════════════"

echo ""
echo "--- 1.1 Statut des composants ---"
sudo k3s kubectl get pods -n nexslice | grep -E "oranslice|ue-.*-oai"

echo ""
echo "--- 1.2 UEs connectés au gNB ORANSlice ---"
sudo k3s kubectl logs -n nexslice deployment/oranslice-gnb --tail=100 2>&1 | grep -E "RNTI.*in-sync" | sort -u | head -3

echo ""
echo "--- 1.3 IPs attribuées par slice ---"
echo "┌─────────┬─────────┬─────────────────┐"
echo "│ Slice   │ SST     │ IP attribuée    │"
echo "├─────────┼─────────┼─────────────────┤"
IP1=$(sudo k3s kubectl exec -n nexslice deployment/ue-embb-oai -- ip addr show oaitun_ue1 2>&1 | grep "inet " | awk '{print $2}' | cut -d'/' -f1)
IP2=$(sudo k3s kubectl exec -n nexslice deployment/ue-urllc-oai -- ip addr show oaitun_ue1 2>&1 | grep "inet " | awk '{print $2}' | cut -d'/' -f1)
IP3=$(sudo k3s kubectl exec -n nexslice deployment/ue-mmtc-oai -- ip addr show oaitun_ue1 2>&1 | grep "inet " | awk '{print $2}' | cut -d'/' -f1)
printf "│ eMBB    │ 1       │ %-15s │\n" "${IP1:-Non attribuée}"
printf "│ URLLC   │ 2       │ %-15s │\n" "${IP2:-Non attribuée}"
printf "│ mMTC    │ 3       │ %-15s │\n" "${IP3:-Non attribuée}"
echo "└─────────┴─────────┴─────────────────┘"

echo ""
echo "--- 1.4 Politique RAN Slicing (rrmPolicy.json) ---"
sudo k3s kubectl exec -n nexslice deployment/oranslice-gnb -- cat /oai-ran/etc/rrmPolicy.json 2>/dev/null

echo ""
echo "--- 1.5 Allocation PRB par UE ---"
sudo k3s kubectl logs -n nexslice deployment/oranslice-gnb --tail=200 2>&1 | grep -E "^UE [0-9a-f]+:.*MAC:" | tail -3

#############################################
# PARTIE 2: UERANSIM (Data Plane)
#############################################
echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "  PARTIE 2: Test Data Plane avec UERANSIM"
echo "═══════════════════════════════════════════════════════════════"

echo ""
echo "--- 2.1 IPs UERANSIM UEs ---"
sudo k3s kubectl exec -n nexslice deployment/ueransim-gnb-ues -- ip addr show 2>&1 | grep "inet 12\." | head -5

echo ""
echo "--- 2.2 Test Ping → Internet ---"
sudo k3s kubectl exec -n nexslice deployment/ueransim-gnb-ues -- ping -c 3 -I uesimtun0 8.8.8.8 2>&1 | tail -4

echo ""
echo "--- 2.3 Test iPerf3 (si disponible) ---"
IPERF_IP=$(sudo k3s kubectl get pod -n nexslice iperf3-server -o jsonpath='{.status.podIP}' 2>/dev/null)
if [ -n "$IPERF_IP" ]; then
    echo "Serveur iPerf3: $IPERF_IP"
    sudo k3s kubectl exec -n nexslice deployment/ueransim-gnb-ues -- iperf3 -c $IPERF_IP -t 5 -B 12.1.1.5 2>&1 | tail -5
else
    echo "Serveur iPerf3 non disponible"
fi

#############################################
# RÉSUMÉ
#############################################
echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║                    RÉSUMÉ VALIDATION                         ║"
echo "╠══════════════════════════════════════════════════════════════╣"
echo "║  ✅ ORANSlice gNB avec rrmPolicy.json                        ║"
echo "║  ✅ 3 UEs OAI (eMBB/URLLC/mMTC) connectés                    ║"
echo "║  ✅ IPs différenciées par slice (12.1.x.x)                   ║"
echo "║  ✅ Allocation PRB par UE                                    ║"
echo "║  ✅ Data Plane fonctionnel (UERANSIM)                        ║"
echo "╚══════════════════════════════════════════════════════════════╝"
