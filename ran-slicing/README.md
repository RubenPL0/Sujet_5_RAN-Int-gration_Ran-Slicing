# NexSlice - RAN Slicing Statique

## 📁 Structure

```
ran-slicing/
├── configs/
│   ├── rrmPolicy.json         # Politique d'allocation PRB par slice
│   └── gnb-slicing.conf       # Configuration gNB slice-aware
├── scripts/
│   ├── patch-oai-scheduler.sh # Patch du scheduler OAI
│   └── deploy-ran-slicing.sh  # Déploiement automatique
└── monitoring/
    └── check-prb-allocation.sh # Vérification allocation PRB
```

## 🚀 Installation

### 1. Appliquer la configuration RAN Slicing

```bash
cd ~/NexSlice
./ran-slicing/scripts/deploy-ran-slicing.sh
```

### 2. Vérifier le déploiement

```bash
sudo k3s kubectl get pods -n nexslice -l app=oai-gnb-slicing
```

### 3. Vérifier les logs

```bash
sudo k3s kubectl logs -n nexslice -l app=oai-gnb-slicing -f | grep SLICING
```

## 📊 Politique d'Allocation PRB

| Slice | S-NSSAI | Min PRB | Max PRB | Weight |
|-------|---------|---------|---------|--------|
| eMBB | 01-000001 | 42 (40%) | 106 (100%) | 4 |
| URLLC | 01-000002 | 32 (30%) | 85 (80%) | 3 |
| mMTC | 01-000003 | 11 (10%) | 53 (50%) | 1 |

## 🧪 Tests

Exécuter le script de test amélioré:

```bash
cd ~/NexSlice
./tests/TEST_ran_slicing.sh
```

## 📈 Monitoring

Vérifier l'allocation PRB en temps réel:

```bash
./ran-slicing/monitoring/check-prb-allocation.sh
```

## ⚙️ Configuration

Modifier `ran-slicing/configs/rrmPolicy.json` puis redéployer:

```bash
helm upgrade oai-gnb-slicing ./5g_ran/oai-gnb-slicing -n nexslice
```

## 🔍 Troubleshooting

### Problème: Le gNB ne démarre pas

```bash
kubectl describe pod -n nexslice -l app=oai-gnb-slicing
kubectl logs -n nexslice -l app=oai-gnb-slicing
```

### Problème: UEs ne se connectent pas

Vérifier que les S-NSSAI correspondent:
- Core: SMF/UPF configurations
- RAN: rrmPolicy.json
- UE: UERANSIM configs

## 📚 Documentation

- Configuration détaillée: `configs/rrmPolicy.json`
- Logs gNB: `kubectl logs -n nexslice <gnb-pod>`
- Métriques: Via Grafana (si monitoring activé)
