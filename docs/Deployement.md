# Guide de Déploiement et Test ORANSlice + NexSlice

Ce guide explique comment déployer ORANSlice (gNB) avec le coeur 5G NexSlice sur K3s, puis valider l'intégration RAN Slicing.

## Prérequis

- Cluster K3s fonctionnel avec NexSlice déployé
- Namespace `nexslice` avec le coeur 5G opérationnel (AMF, SMF, UPFs, NSSF, etc.)
- 3 UPFs configurés pour les 3 slices (oai-upf, oai-upf2, oai-upf3)
- Subscribers configurés en base de données MongoDB

---

## 1. Vérification du Coeur 5G

Avant de déployer ORANSlice, vérifier que le coeur NexSlice est opérationnel :

```bash
# Vérifier les pods du coeur 5G
kubectl get pods -n nexslice | grep -E "amf|smf|upf|nssf|nrf|udr|udm|ausf"

# Tous les pods doivent être Running et Ready
```

### Résultat attendu

```
oai-amf-xxx          1/1     Running
oai-smf-xxx          1/1     Running
oai-upf-xxx          1/1     Running
oai-upf2-xxx         1/1     Running
oai-upf3-xxx         1/1     Running
oai-nssf-xxx         1/1     Running
...
```

---

## 2. Configuration des Subscribers

Les 3 UEs doivent être configurés en base MongoDB avec leurs S-NSSAI respectifs.

### Script SQL pour MongoDB

```bash
# Se connecter au pod MongoDB
kubectl exec -it mongodb-0 -n nexslice -- mongosh

# Dans le shell mongo, exécuter :
use open5gs

# UE eMBB (IMSI 208950000000041, SST=1)
db.subscribers.insertOne({
  "imsi": "208950000000041",
  "subscribed_snssai": [{"sst": 1, "sd": "0x010203"}],
  "slice": [{"sst": 1, "sd": "0x010203", "dnn": "oai"}]
})

# UE URLLC (IMSI 208950000000042, SST=2)
db.subscribers.insertOne({
  "imsi": "208950000000042",
  "subscribed_snssai": [{"sst": 2, "sd": "0x010203"}],
  "slice": [{"sst": 2, "sd": "0x010203", "dnn": "oai2"}]
})

# UE mMTC (IMSI 208950000000043, SST=3)
db.subscribers.insertOne({
  "imsi": "208950000000043",
  "subscribed_snssai": [{"sst": 3, "sd": "0x010203"}],
  "slice": [{"sst": 3, "sd": "0x010203", "dnn": "oai3"}]
})
```

---

## 3. Déploiement ORANSlice gNB

### 3.1 Appliquer les ConfigMaps

```bash
# ConfigMap de configuration gNB
kubectl apply -f k3s/configmap-gnb-current.yaml -n nexslice

# ConfigMap de politique RRM (allocation PRBs par slice)
kubectl apply -f k3s/configmap-rrmpolicy.yaml -n nexslice
```

### 3.2 Déployer le gNB

```bash
# Déploiement du gNB ORANSlice avec RFsimulator
kubectl apply -f k3s/deployment-oranslice-rfsim.yaml -n nexslice

# Service pour exposer le gNB
kubectl apply -f k3s/service-oranslice.yaml -n nexslice
```

### 3.3 Vérifier le déploiement

```bash
# Attendre que le pod soit Running
kubectl get pods -n nexslice | grep oranslice

# Vérifier les logs de démarrage
kubectl logs -n nexslice deployment/oranslice-gnb --tail=50
```

### Résultat attendu

Le gNB doit afficher :
- `Initializing gNB`
- `NGAP: Connected to AMF`
- `Slices configured: 3`

---

## 4. Déploiement des UEs

### 4.1 Déployer les 3 UEs

```bash
# Déploiement des 3 UEs (eMBB, URLLC, mMTC)
kubectl apply -f k3s/ues-3slices-rfsim.yaml -n nexslice
```

### 4.2 Vérifier les UEs

```bash
# Vérifier que les 3 pods UE sont Running
kubectl get pods -n nexslice | grep ue-

# Résultat attendu :
# ue-embb-oai-xxx     1/1     Running
# ue-urllc-oai-xxx    1/1     Running
# ue-mmtc-oai-xxx     1/1     Running
```

---

## 5. Validation de l'Intégration

### 5.1 Test rapide (script automatisé)

```bash
# Exécuter le script de validation complet
./scripts/validate-oranslice.sh
```

### 5.2 Tests manuels détaillés

#### A. Vérifier la connexion gNB → AMF

```bash
# Le gNB doit apparaître dans les logs AMF
kubectl logs -n nexslice deployment/oai-amf --tail=100 | grep -i "gnb\|NG Setup"

# Résultat attendu : "NG Setup successful" ou "gNB connected"
```

#### B. Vérifier l'enregistrement des UEs

```bash
# UE eMBB (IMSI 041)
kubectl logs -n nexslice deployment/oai-amf --tail=200 | grep "208950000000041"

# UE URLLC (IMSI 042)
kubectl logs -n nexslice deployment/oai-amf --tail=200 | grep "208950000000042"

# UE mMTC (IMSI 043)
kubectl logs -n nexslice deployment/oai-amf --tail=200 | grep "208950000000043"

# Résultat attendu pour chaque UE : "5GMM-REGISTERED"
```

#### C. Vérifier les PDU Sessions

```bash
# Vérifier que chaque UE a une session PDU
kubectl logs -n nexslice deployment/oai-smf --tail=100 | grep -i "pdu session\|allocated"

# Vérifier les IPs attribuées par UPF
kubectl exec -n nexslice deployment/ue-embb-oai -- ip addr show oaitun_ue1
kubectl exec -n nexslice deployment/ue-urllc-oai -- ip addr show oaitun_ue1
kubectl exec -n nexslice deployment/ue-mmtc-oai -- ip addr show oaitun_ue1

# Résultat attendu :
# UE eMBB  → 12.1.1.x (UPF1)
# UE URLLC → 12.1.2.x (UPF2)
# UE mMTC  → 12.1.3.x (UPF3)
```

#### D. Vérifier le RAN Slicing au niveau MAC

```bash
# Vérifier que le scheduler MAC gère les 3 slices
kubectl logs -n nexslice deployment/oranslice-gnb --tail=200 | grep -i "slice"

# Résultat attendu : logs montrant "Slice id 0 (sst=1)", "Slice id 1 (sst=2)", "Slice id 2 (sst=3)"
```

#### E. Vérifier la politique RRM

```bash
# Afficher la politique RRM configurée
kubectl get configmap -n nexslice configmap-rrmpolicy -o jsonpath='{.data.rrmPolicy\.json}' | jq .

# Résultat attendu : ratios PRBs par slice (eMBB 40-80%, URLLC 20-40%, mMTC 5-30%)
```

---

## 6. Tests de Connectivité Data Plane

> **Note** : Le RFsimulator a des limitations connues pour le forwarding data plane. Les pings peuvent échouer même si le control plane fonctionne.

### 6.1 Test Ping (peut échouer)

```bash
# Depuis UE eMBB vers Internet
kubectl exec -n nexslice deployment/ue-embb-oai -- ping -c 3 8.8.8.8

# Depuis UE URLLC
kubectl exec -n nexslice deployment/ue-urllc-oai -- ping -c 3 8.8.8.8

# Depuis UE mMTC
kubectl exec -n nexslice deployment/ue-mmtc-oai -- ping -c 3 8.8.8.8
```

### 6.2 Vérification alternative (tunnels GTP-U)

Si le ping échoue, vérifier que les tunnels sont créés :

```bash
# Vérifier les tunnels GTP sur le gNB
kubectl logs -n nexslice deployment/oranslice-gnb | grep -i "tunnel\|gtp"

# Vérifier les sessions PFCP sur le SMF
kubectl logs -n nexslice deployment/oai-smf | grep -i "pfcp\|session"
```

---

## 7. Tableau Récapitulatif des Validations

| Test | Commande | Résultat Attendu |
|------|----------|------------------|
| gNB connecté AMF | `kubectl logs oai-amf \| grep gnb` | "NG Setup successful" |
| UE 041 enregistré | `kubectl logs oai-amf \| grep 041` | "5GMM-REGISTERED" |
| UE 042 enregistré | `kubectl logs oai-amf \| grep 042` | "5GMM-REGISTERED" |
| UE 043 enregistré | `kubectl logs oai-amf \| grep 043` | "5GMM-REGISTERED" |
| IP UE eMBB | `kubectl exec ue-embb-oai -- ip addr` | 12.1.1.x |
| IP UE URLLC | `kubectl exec ue-urllc-oai -- ip addr` | 12.1.2.x |
| IP UE mMTC | `kubectl exec ue-mmtc-oai -- ip addr` | 12.1.3.x |
| Slices MAC | `kubectl logs oranslice-gnb \| grep slice` | 3 Slice id |
| Politique RRM | `kubectl get configmap rrmpolicy` | Ratios PRBs |

---

## 8. Dépannage

### Le gNB ne se connecte pas à l'AMF

```bash
# Vérifier l'IP de l'AMF
kubectl get svc oai-amf -n nexslice -o jsonpath='{.spec.clusterIP}'

# Vérifier la config du gNB
kubectl get configmap configmap-gnb-current -n nexslice -o yaml | grep amf_ip
```

### Les UEs ne s'enregistrent pas

```bash
# Vérifier la connexion RFsimulator
kubectl logs -n nexslice deployment/ue-embb-oai | grep -i "connect\|rfsim"

# Vérifier les credentials en base
kubectl exec -it mongodb-0 -n nexslice -- mongosh --eval "db.subscribers.find({imsi: '208950000000041'})"
```

### Pas de PDU Session

```bash
# Vérifier le NSSF
kubectl logs -n nexslice deployment/oai-nssf | grep -i "slice\|selection"

# Vérifier que les DNNs correspondent
kubectl logs -n nexslice deployment/oai-smf | grep -i "dnn\|oai"
```

---

## 9. Arrêt et Nettoyage

```bash
# Supprimer les UEs
kubectl delete -f k3s/ues-3slices-rfsim.yaml -n nexslice

# Supprimer le gNB
kubectl delete -f k3s/deployment-oranslice-rfsim.yaml -n nexslice
kubectl delete -f k3s/service-oranslice.yaml -n nexslice

# Supprimer les ConfigMaps
kubectl delete -f k3s/configmap-gnb-current.yaml -n nexslice
kubectl delete -f k3s/configmap-rrmpolicy.yaml -n nexslice
```

---

## Références

- [ORANSlice (WiNeS Lab)](https://github.com/wineslab/ORANSlice) — Projet gNB RAN Slicing.
- [OpenAirInterface 5G RAN](https://gitlab.eurecom.fr/oai/openairinterface5g) — Stack RAN 5G open source.
- [OpenAirInterface 5G Core](https://gitlab.eurecom.fr/oai/cn5g) — Coeur 5G open source.
- [NexSlice (AIDY-F2N)](https://github.com/AIDY-F2N/NexSlice/tree/k3s) — Déploiement NexSlice.
- [3GPP TS 23.501 — System Architecture](https://www.3gpp.org/DynaReport/23501.htm) — Référence architecture système 5G.
- [3GPP TS 38.300 — NR Overall Description](https://www.3gpp.org/DynaReport/38300.htm) — Description générale NR 5G.
