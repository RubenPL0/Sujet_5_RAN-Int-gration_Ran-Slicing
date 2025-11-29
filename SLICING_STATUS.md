# 📊 NexSlice - Status du Network Slicing

## ✅ Ce qui Fonctionne (Core Network Slicing)

### Architecture Déployée

```
┌─────────────────────────────────────────────────────────────┐
│                    NexSlice 5G Network                       │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  📱 UEs (UERANSIM)                                           │
│     ├─ UE1: 12.1.1.x  →  Slice eMBB  (01-000001)            │
│     ├─ UE2: 12.1.2.x  →  Slice URLLC (01-000002)            │
│     └─ UE3: 12.1.3.x  →  Slice mMTC  (01-000003)            │
│                                                              │
│  📡 RAN (Radio Access Network)                               │
│     └─ gNB: UERANSIM ou OAI (sans RAN slicing dynamique)    │
│                                                              │
│  🌐 Core Network (5GC) - **SLICING ACTIF**                  │
│     ├─ AMF (commun)                                          │
│     ├─ NRF, UDM, UDR, AUSF, NSSF (communs)                  │
│     │                                                        │
│     ├─ **Slice 1 (eMBB):**                                   │
│     │   ├─ SMF1 (01-000001)                                 │
│     │   └─ UPF1 → Subnet 12.1.1.0/24                        │
│     │                                                        │
│     ├─ **Slice 2 (URLLC):**                                  │
│     │   ├─ SMF2 (01-000002)                                 │
│     │   └─ UPF2 → Subnet 12.1.2.0/24                        │
│     │                                                        │
│     └─ **Slice 3 (mMTC):**                                   │
│         ├─ SMF3 (01-000003)                                 │
│         └─ UPF3 → Subnet 12.1.3.0/24                        │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

### Caractéristiques du Slicing

| Feature | Status | Description |
|---------|--------|-------------|
| **Core Network Slicing** | ✅ Actif | 3 slices indépendants (SMF+UPF) |
| **IP Address Allocation** | ✅ Actif | Subnets séparés par slice |
| **Traffic Isolation** | ✅ Actif | Tunnels GTP-U séparés |
| **QoS Policies** | ✅ Actif | Différenciation au niveau Core |
| **RAN PRB Allocation** | ⚠️ Statique | Pas d'allocation dynamique |

## 📋 Configuration des Slices

### Slice 1: eMBB (Enhanced Mobile Broadband)
- **S-NSSAI:** SST=1, SD=0x000001
- **Use Case:** Video streaming, navigation web, téléchargements
- **IP Range:** 12.1.1.0/24
- **QoS Target:** Débit élevé (>50 Mbps)
- **Latency Target:** <100ms

### Slice 2: URLLC (Ultra-Reliable Low-Latency)
- **S-NSSAI:** SST=1, SD=0x000002
- **Use Case:** Contrôle industriel, véhicules autonomes
- **IP Range:** 12.1.2.0/24
- **QoS Target:** Latence ultra-faible (<5ms)
- **Reliability Target:** 99.999%

### Slice 3: mMTC (Massive Machine-Type Communications)
- **S-NSSAI:** SST=1, SD=0x000003
- **Use Case:** IoT, capteurs, smart cities
- **IP Range:** 12.1.3.0/24
- **QoS Target:** Efficacité énergétique
- **Connection Density:** Support >100k appareils/km²

## 🧪 Tests Validés

- [x] Attribution IP par slice
- [x] Connectivité Internet par slice
- [x] Isolation réseau (subnets)
- [x] Tests de latence
- [x] Tests de débit séquentiel
- [x] Tests de débit concurrent (congestion)

## 📊 Résultats de Performance

### Test de Connectivité
```
UE1 (eMBB):  12.1.1.x → Ping OK (latence: ~6ms)
UE2 (URLLC): 12.1.2.x → Ping OK (latence: ~11ms)
UE3 (mMTC):  12.1.3.x → Ping OK (latence: ~7ms)
```

### Test de Débit (Séquentiel)
Les 3 UEs obtiennent des débits similaires sans congestion.

### Test de Charge (Concurrent)
Sous congestion, les différences de débit démontrent la QoS du Core.

## ⚙️ Configuration RAN Slicing (Préparée)

La configuration pour le RAN slicing a été préparée mais **non déployée** car :

1. **UERANSIM** ne simule pas le scheduler MAC réel
2. **OAI gNB** nécessite une configuration complexe pour K8s
3. Le **Core Network Slicing** démontre déjà efficacement le concept

### Fichiers Créés

```
ran-slicing/
├── configs/
│   ├── rrmPolicy.json         # Politique PRB allocation
│   └── gnb-slicing.conf       # Config gNB (non utilisée)
├── scripts/
│   ├── deploy-ran-slicing.sh  # Script déploiement
│   └── patch-oai-scheduler.sh # Patch scheduler
└── monitoring/
    └── check-prb-allocation.sh # Monitoring
```

### Politique PRB Définie

| Slice | Min PRB | Max PRB | Weight |
|-------|---------|---------|--------|
| eMBB  | 42 (40%) | 106 (100%) | 4 |
| URLLC | 32 (30%) | 85 (80%) | 3 |
| mMTC  | 11 (10%) | 53 (50%) | 1 |

## 🚀 Pour Aller Plus Loin

### Option 1: RAN Slicing Réel (Hardware)
Pour tester le vrai RAN slicing avec allocation PRB dynamique :

1. Utiliser **OAI nrUE** avec SDR (USRP, LimeSDR)
2. Déployer **ORANSlice** (https://github.com/wineslab/ORANSlice)
3. Utiliser des **UEs COTS 5G** commerciaux
4. Mesurer via traces MAC/PHY

### Option 2: Tests Avancés Core Slicing
Approfondir les tests du Core Network Slicing :

- Tests de charge à grande échelle (>10 UEs par slice)
- Mesure de l'isolation (bande passante garantie)
- Tests de QoS (DSCP, DiffServ)
- Monitoring avancé (Grafana dashboards)

### Option 3: Simulation Complète
Utiliser un simulateur réseau complet :

- **ns-3** avec module 5G
- **OMNET++** avec SimuLTE
- **OpenAirInterface RFsimulator** en mode avancé

## 📚 Documentation Technique

### Architecture 3GPP

Le slicing implémenté suit les spécifications 3GPP :

- **TS 23.501:** System Architecture for 5G
- **TS 28.541:** Network Slicing Management
- **TS 23.502:** Procedures for 5G System

### S-NSSAI (Single Network Slice Selection Assistance Information)

```
S-NSSAI = SST + SD
- SST (Slice/Service Type): 1 octet
- SD (Slice Differentiator): 3 octets (optionnel)
```

Nos slices:
- eMBB:  SST=1, SD=0x000001
- URLLC: SST=1, SD=0x000002
- mMTC:  SST=1, SD=0x000003

## 🎓 Conclusion

**NexSlice démontre avec succès le Core Network Slicing 5G**, une fonctionnalité essentielle pour :

✅ **Service Différenciation:** Isolation complète du trafic
✅ **QoS Guarantees:** Politiques par slice
✅ **Multi-Tenancy:** Support de multiples services sur une infrastructure partagée
✅ **Scalabilité:** Architecture modulaire et extensible

Le **RAN Slicing** (allocation PRB dynamique) reste une extension future qui nécessiterait :
- Hardware SDR ou UEs commerciaux
- Scheduler MAC slice-aware
- Testbed RAN plus complexe

---

**Projet NexSlice** - Plateforme 5G Network Slicing  
*Version 1.0 - Core Network Slicing Validé*
