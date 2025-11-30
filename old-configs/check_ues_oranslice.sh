#!/bin/bash
echo "═══════════════════════════════════════════════════════════════"
echo "           ORANSlice UEs Status Report"
echo "═══════════════════════════════════════════════════════════════"
echo ""

echo "1️⃣  UE PODS STATUS"
echo "───────────────────────────────────────────────────────────────"
sudo kubectl get pods -n nexslice | grep -E "NAME|ue-embb|ue-urllc|ue-mmtc"
echo ""

echo "2️⃣  UE CONNECTIONS (RFsimulator)"
echo "───────────────────────────────────────────────────────────────"
for UE in ue-embb ue-urllc ue-mmtc; do
    echo "📱 $UE:"
    POD=$(sudo kubectl get pods -n nexslice -l app=$UE -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    if [ ! -z "$POD" ]; then
        CONN=$(sudo kubectl logs -n nexslice $POD 2>/dev/null | grep -E "Connection to oranslice-gnb|IMSI|SST|SD" | head -3)
        echo "$CONN" | sed 's/^/  /'
    fi
    echo ""
done

echo "3️⃣  AMF REGISTERED UEs"
echo "───────────────────────────────────────────────────────────────"
sudo kubectl logs -n nexslice $(sudo kubectl get pods -n nexslice -o name | grep amf) --tail=100 2>/dev/null | grep -A20 "UEs' Information" | tail -20

echo ""
echo "4️⃣  ORANSLICE gNB STATUS"
echo "───────────────────────────────────────────────────────────────"
sudo kubectl get pods -n nexslice | grep oranslice
echo ""
AMF_STATUS=$(sudo kubectl logs -n nexslice $(sudo kubectl get pods -n nexslice -o name | grep amf) --tail=50 2>/dev/null | grep ORANSlice | tail -1)
echo "AMF Connection: $AMF_STATUS"

echo ""
echo "5️⃣  CONFIGURED SLICES"
echo "───────────────────────────────────────────────────────────────"
sudo kubectl logs -n nexslice -l app=oranslice-gnb 2>/dev/null | grep -A5 "Configured slices at MAC" | tail -6

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "Report generated at: $(date)"
echo "═══════════════════════════════════════════════════════════════"
