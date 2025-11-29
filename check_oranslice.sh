#!/bin/bash
echo "=== ORANSlice gNB Status ==="
echo ""
echo "Pod Status:"
sudo kubectl get pods -n nexslice | grep oranslice
echo ""
echo "AMF Connection:"
sudo kubectl logs -n nexslice $(sudo kubectl get pods -n nexslice -o name | grep amf) --tail=20 | grep -A3 "gNBs' Information" | grep ORANSlice
echo ""
echo "Configured Slices:"
sudo kubectl logs -n nexslice -l app=oranslice-gnb | grep -A5 "Configured slices" | tail -6
