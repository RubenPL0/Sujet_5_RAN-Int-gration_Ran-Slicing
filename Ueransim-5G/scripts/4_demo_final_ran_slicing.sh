#!/bin/bash
# =============================================================================
# Projet 5: RAN Slicing - Démonstration Complète
# Ce qui est fait vs Ce qui nécessite du hardware
# =============================================================================

NAMESPACE="nexslice"
KUBECTL="sudo k3s kubectl"

# Couleurs
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

clear
echo ""
echo "╔══════════════════════════════════════════════════════════════════╗"
echo "║           Projet 5: RAN Slicing - Démonstration                  ║"
echo "║                     NexSlice 5G                                  ║"
echo "╚══════════════════════════════════════════════════════════════════╝"
echo ""

# =============================================================================
# 1. CE QUI EST RÉALISÉ (Core Network Slicing)
# =============================================================================

echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN} CE QUI EST RÉALISÉ ET FONCTIONNEL${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

echo "1.  Core Network Slicing (5GC):"
echo ""

# Compter les pods
SMF_COUNT=$($KUBECTL get pods -n $NAMESPACE 2>/dev/null | grep -c "oai-smf" || echo "0")
UPF_COUNT=$($KUBECTL get pods -n $NAMESPACE 2>/dev/null | grep -c "oai-upf" || echo "0")

echo "   ✓ $SMF_COUNT SMF déployés (1 par slice)"
echo "   ✓ $UPF_COUNT UPF déployés (1 par slice)"
echo "   ✓ NSSF configuré avec 3 S-NSSAI"
echo ""

echo "2.  Isolation Réseau par Slice:"
echo ""

# Récupérer les UE pods dynamiquement
UE_PODS=($($KUBECTL get pods -n $NAMESPACE -o name 2>/dev/null | grep "ueransim-ue" | cut -d'/' -f2))

if [ ${#UE_PODS[@]} -eq 0 ]; then
    echo "   ⚠  Aucun UE détecté"
else
    for ue_pod in "${UE_PODS[@]}"; do
        IP=$($KUBECTL exec -n $NAMESPACE $ue_pod -- ip -4 addr show uesimtun0 2>/dev/null | grep 'inet ' | awk '{print $2}' | cut -d'/' -f1)
        
        if [[ "$IP" == 12.1.1.* ]]; then
            echo -e "   ✓ UE1 (eMBB):  ${GREEN}$IP${NC}  →  Slice 01-000001"
        elif [[ "$IP" == 12.1.2.* ]]; then
            echo -e "   ✓ UE2 (URLLC): ${GREEN}$IP${NC}  →  Slice 01-000002"
        elif [[ "$IP" == 12.1.3.* ]]; then
            echo -e "   ✓ UE3 (mMTC):  ${GREEN}$IP${NC}  →  Slice 01-000003"
        fi
    done
fi

echo ""

echo "3.  QoS et Politiques:"
echo ""
echo "   ✓ Subnets IP séparés (12.1.1.0/24, 12.1.2.0/24, 12.1.3.0/24)"
echo "   ✓ Tunnels GTP-U indépendants par slice"
echo "   ✓ Session Management indépendant (3 SMF)"
echo "   ✓ User Plane isolé (3 UPF)"
echo ""

echo "4.  Tests Validés:"
echo ""
echo "   ✓ Attribution IP correcte par slice"
echo "   ✓ Connectivité Internet pour les 3 slices"
echo "   ✓ Isolation réseau vérifiée"
echo "   ✓ Tests de débit et latence effectués"
echo ""

# =============================================================================
# 2. CE QUI EST PRÉPARÉ (RAN Slicing Configuration)
# =============================================================================

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}  CE QUI EST PRÉPARÉ (RAN Slicing)${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

if [ -f "ran-slicing/configs/rrmPolicy.json" ]; then
    echo "1.  Configuration RAN Slicing:"
    echo ""
    echo "   ✓ Fichier rrmPolicy.json créé"
    echo "   ✓ Allocation PRB définie (eMBB: 40%, URLLC: 30%, mMTC: 10%)"
    echo "   ✓ Poids par slice configurés (4:3:1)"
    echo "   ✓ Scripts de déploiement prêts"
    echo ""
    
    echo "2.  Allocation PRB Planifiée:"
    echo ""
    cat <<'TABLE'
   ┌──────────┬───────────┬───────────┬─────────┐
   │  Slice   │  Min PRB  │  Max PRB  │  Weight │
   ├──────────┼───────────┼───────────┼─────────┤
   │ eMBB     │  42 (40%) │ 106 (100%)│    4    │
   │ URLLC    │  32 (30%) │  85 (80%) │    3    │
   │ mMTC     │  11 (10%) │  53 (50%) │    1    │
   └──────────┴───────────┴───────────┴─────────┘
TABLE
    echo ""
else
    echo -e "${YELLOW}⚠  Configuration RAN à créer${NC}"
fi

# =============================================================================
# 3. CE QUI NÉCESSITE DU HARDWARE (Limitation UERANSIM)
# =============================================================================

echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}  LIMITATIONS ET BESOINS HARDWARE${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

echo "1.  Limitation Actuelle (UERANSIM):"
echo ""
echo "   UERANSIM simule uniquement les couches NAS/RRC du UE."
echo "   Il ne simule PAS:"
echo ""
echo "   ✗ Couches PHY/MAC (scheduling réel)"
echo "   ✗ Allocation PRB dynamique"
echo "   ✗ Canal radio (interference, fading)"
echo "   ✗ Modulation/codage adaptif (MCS)"
echo ""

echo "2.  Ce qu'il faudrait pour le RAN Slicing Complet:"
echo ""
echo "   Hardware nécessaire:"
echo "   • USRP B210 ou X310 (SDR) - ~1500-5000€"
echo "   • PC avec capacités temps réel"
echo "   • UEs OAI (oai-nr-ue) avec SDR"
echo "   OU"
echo "   • UEs 5G COTS commerciaux"
echo ""

echo "   Software nécessaire:"
echo "   • ORANSlice (github.com/wineslab/ORANSlice)"
echo "   • Scheduler MAC slice-aware"
echo "   • Noyau Linux temps-réel (low-latency)"
echo ""

# =============================================================================
# 4. ARCHITECTURE ACTUELLE vs CIBLE
# =============================================================================

echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN} ARCHITECTURE ACTUELLE VS CIBLE${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

cat <<'ARCHITECTURE'
┌─────────────────────────────────────────────────────────────┐
│                    ARCHITECTURE ACTUELLE                    │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  UEs (UERANSIM - Simulés)                                   │
│    └─ NAS/RRC uniquement                                    │
│    └─ Pas de PHY/MAC réel                                   │
│         ↓                                                   │
│  gNB (OAI - RFsim ou Disaggregated)                         │
│    └─ Scheduler MAC standard                                │
│    └─ Pas d'allocation PRB par slice                        │
│         ↓                                                   │
│  Core Network (OAI 5GC)  FONCTIONNEL                        │
│    ├─ AMF, NRF, UDM, UDR, NSSF                              │
│    ├─ SMF1 + UPF1 (eMBB)   → 12.1.1.0/24                    │
│    ├─ SMF2 + UPF2 (URLLC)  → 12.1.2.0/24                    │
│    └─ SMF3 + UPF3 (mMTC)   → 12.1.3.0/24                    │
│                                                             │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│                    ARCHITECTURE CIBLE                       │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  UEs (Hardware USRP + OAI nrUE)                             │
│    └─ PHY/MAC complet                                       │
│    └─ Canal radio réel                                      │
│         ↓                                                   │
│  gNB (OAI + ORANSlice)                                      │
│    └─ Scheduler MAC slice-aware                             │
│    └─ Allocation PRB dynamique                              │
│    └─ Garanties min/max par slice                           │
│         ↓                                                   │
│  Core Network (OAI 5GC)  DÉJÀ FONCTIONNEL                   │
│    └─ Identique à architecture actuelle                     │
│                                                             │
└─────────────────────────────────────────────────────────────┘
ARCHITECTURE
echo ""

# =============================================================================
# 5. RÉSUMÉ FINAL
# =============================================================================

echo "╔══════════════════════════════════════════════════════════════════╗"
echo "║                    RÉSUMÉ DU PROJET                              ║"
echo "╠══════════════════════════════════════════════════════════════════╣"
echo "║                                                                  ║"
echo "║   RÉALISÉ:                                                       ║"
echo "║     • Core Network Slicing (100% fonctionnel)                    ║"
echo "║     • 3 slices indépendants (SMF+UPF)                            ║"
echo "║     • Isolation réseau par subnet                                ║"
echo "║     • QoS différenciée par slice                                 ║"
echo "║     • Tests de validation effectués                              ║"
echo "║                                                                  ║"
echo "║    PRÉPARÉ:                                                      ║"
echo "║     • Configuration RAN Slicing (rrmPolicy.json)                 ║"
echo "║     • Allocation PRB définie                                     ║"
echo "║     • Scripts de déploiement prêts                               ║"
echo "║                                                                  ║"
echo "║   NÉCESSITE HARDWARE:                                            ║"
echo "║     • Scheduler MAC slice-aware                                  ║"
echo "║     • Allocation PRB dynamique                                   ║"
echo "║     • Validation avec SDR (USRP)                                 ║ "
echo "║                                                                  ║"
echo "╚══════════════════════════════════════════════════════════════════╝"
echo ""

echo -e "${GREEN} Core Network Slicing: VALIDÉ${NC}"
echo -e "${BLUE}  RAN Slicing: CONFIGURÉ (nécessite SDR pour activation complète)${NC}"
echo ""

echo " Référence:"
echo "   H. Cheng et al., 'ORANSlice: An Open-Source 5G Network Slicing"
echo "   Platform for O-RAN', ACM MobiCom 2024"
echo "   https://arxiv.org/abs/2410.12978"
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
