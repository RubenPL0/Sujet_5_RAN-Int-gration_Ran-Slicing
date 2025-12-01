# Notice de Déploiement et Test ORANSlice + NexSlice

## Prérequis

- Cluster K3s fonctionnel avec NexSlice déployé
- Namespace `nexslice` avec le cœur 5G opérationnel (AMF, SMF, UPFs, NSSF, etc.)
- 3 UPFs configurés pour les 3 slices (oai-upf, oai-upf2, oai-upf3)


---

## 1. Vérification du Cœur 5G

Avant de déployer ORANSlice, vérifier que le cœur NexSlice est opérationnel :

```bash
# Vérifier les pods du cœur 5G
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

## 2. Déploiement ORANSlice gNB

```bash
# Déploiement autotmatisé
./deploy.sh
```

### 2.1 Appliquer les ConfigMaps

```bash
# ConfigMap de configuration gNB
kubectl apply -f k3s/configmap-gnb-current.yaml -n nexslice

# ConfigMap de politique RRM (allocation PRBs par slice)
kubectl apply -f k3s/configmap-rrmpolicy.yaml -n nexslice
```

### 2.2 Déployer le gNB

```bash
# Déploiement du gNB ORANSlice avec RFsimulator
kubectl apply -f k3s/deployment-oranslice-rfsim.yaml -n nexslice

# Service pour exposer le gNB
kubectl apply -f k3s/service-oranslice.yaml -n nexslice
```

### 2.3 Vérifier le déploiement

```bash
# Attendre que le pod soit Running
kubectl get pods -n nexslice | grep oranslice

# Vérifier les logs de démarrage
kubectl logs -n nexslice -l app=oranslice-gnb --tail=50
```

### Résultat attendu

Le gNB doit afficher :

- `Initializing gNB`
- `NGAP: Connected to AMF`
- `Slices configured: 3`

---

## 3. Déploiement des UEs

### 3.1 Déployer les 3 UEs

```bash
# Déploiement des 3 UEs (eMBB, URLLC, mMTC)
kubectl apply -f k3s/ues-3slices-rfsim.yaml -n nexslice
```

### 3.2 Vérifier les UEs

```bash
# Vérifier que les 3 pods UE sont Running
kubectl get pods -n nexslice | grep ue-

# Résultat attendu :
# ue-embb-xxx     1/1     Running
# ue-urllc-xxx    1/1     Running
# ue-mmtc-xxx     1/1     Running
```

---

## 4. Validation de l'Intégration

### 4.1 Test rapide (script automatisé)

```bash
# Exécuter le script de validation complet
./scripts/validate-oranslice.sh
```

### 4.2 Tests manuels détaillés

#### A. Vérifier la connexion gNB → AMF

```bash
# Le gNB doit apparaître dans les logs AMF
kubectl logs -n nexslice -l app=oai-amf --tail=100 | grep -i "gnb\|NG Setup"

# Résultat attendu : "NG Setup successful" ou "gNB connected"
```

#### B. Vérifier l'enregistrement des UEs

```bash
# UE eMBB (IMSI 041)
kubectl logs -n nexslice -l app=oai-amf --tail=200 | grep "208950000000041"

# UE URLLC (IMSI 042)
kubectl logs -n nexslice -l app=oai-amf --tail=200 | grep "208950000000042"

# UE mMTC (IMSI 043)
kubectl logs -n nexslice -l app=oai-amf --tail=200 | grep "208950000000043"

# Résultat attendu pour chaque UE : "5GMM-REGISTERED"
```

#### C. Vérifier les PDU Sessions

```bash
# Vérifier que chaque UE a une session PDU
kubectl logs -n nexslice -l app=oai-smf --tail=100 | grep -i "pdu session\|allocated"

# Vérifier les IPs attribuées par UPF
kubectl exec -n nexslice -l app=ue-embb -- ip addr show oaitun_ue1
kubectl exec -n nexslice -l app=ue-urllc -- ip addr show oaitun_ue1
kubectl exec -n nexslice -l app=ue-mmtc -- ip addr show oaitun_ue1

# Résultat attendu :
# UE eMBB  → 12.1.1.x (UPF1)
# UE URLLC → 12.1.2.x (UPF2)
# UE mMTC  → 12.1.3.x (UPF3)
```

#### D. Vérifier le RAN Slicing au niveau MAC

```bash
# Vérifier que le scheduler MAC gère les 3 slices
kubectl logs -n nexslice -l app=oranslice-gnb --tail=200 | grep -i "slice"

# Résultat attendu : logs montrant "Slice id 0 (sst=1)", "Slice id 1 (sst=2)", "Slice id 2 (sst=3)"
```

#### E. Vérifier la politique RRM

```bash
# Afficher la politique RRM configurée
kubectl get configmap configmap-rrmpolicy -n nexslice -o jsonpath='{.data.rrmPolicy\.json}' | jq .

# Résultat attendu : ratios PRBs par slice (eMBB 40-80%, URLLC 20-40%, mMTC 5-30%)
```

---

## 5. Tests de Connectivité Data Plane

> **Note** : Le RFsimulator a des limitations connues pour le forwarding data plane. Les pings peuvent échouer même si le control plane fonctionne.

### 5.1 Test Ping (peut échouer)

```bash
# Récupérer le nom exact des pods
UE_EMBB=$(kubectl get pod -n nexslice -l app=ue-embb -o jsonpath='{.items[0].metadata.name}')
UE_URLLC=$(kubectl get pod -n nexslice -l app=ue-urllc -o jsonpath='{.items[0].metadata.name}')
UE_MMTC=$(kubectl get pod -n nexslice -l app=ue-mmtc -o jsonpath='{.items[0].metadata.name}')

# Depuis UE eMBB vers Internet
kubectl exec -n nexslice $UE_EMBB -- ping -c 3 8.8.8.8

# Depuis UE URLLC
kubectl exec -n nexslice $UE_URLLC -- ping -c 3 8.8.8.8

# Depuis UE mMTC
kubectl exec -n nexslice $UE_MMTC -- ping -c 3 8.8.8.8
```

### 5.2 Vérification alternative (tunnels GTP-U)

Si le ping échoue, vérifier que les tunnels sont créés :

```bash
# Vérifier les tunnels GTP sur le gNB
kubectl logs -n nexslice -l app=oranslice-gnb | grep -i "tunnel\|gtp"

# Vérifier les sessions PFCP sur le SMF
kubectl logs -n nexslice -l app=oai-smf | grep -i "pfcp\|session"
```

---

## 6. Tableau Récapitulatif des Validations

| Test | Commande | Résultat Attendu |
|------|----------|------------------|
| gNB connecté AMF | `kubectl logs -n nexslice -l app=oai-amf \| grep gnb` | "NG Setup successful" |
| UE 041 enregistré | `kubectl logs -n nexslice -l app=oai-amf \| grep 041` | "5GMM-REGISTERED" |
| UE 042 enregistré | `kubectl logs -n nexslice -l app=oai-amf \| grep 042` | "5GMM-REGISTERED" |
| UE 043 enregistré | `kubectl logs -n nexslice -l app=oai-amf \| grep 043` | "5GMM-REGISTERED" |
| IP UE eMBB | `kubectl exec -n nexslice $UE_EMBB -- ip addr` | 12.1.1.x |
| IP UE URLLC | `kubectl exec -n nexslice $UE_URLLC -- ip addr` | 12.1.2.x |
| IP UE mMTC | `kubectl exec -n nexslice $UE_MMTC -- ip addr` | 12.1.3.x |
| Slices MAC | `kubectl logs -n nexslice -l app=oranslice-gnb \| grep slice` | 3 Slice id |
| Politique RRM | `kubectl get configmap configmap-rrmpolicy -n nexslice` | Ratios PRBs |

---

## 7. Dépannage

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
kubectl logs -n nexslice -l app=ue-embb | grep -i "connect\|rfsim"

# Vérifier les credentials en base
kubectl exec -it mongodb-0 -n nexslice -- mongosh --eval "use open5gs; db.subscribers.find({imsi: '208950000000041'}).pretty()"
```

### Pas de PDU Session

```bash
# Vérifier le NSSF
kubectl logs -n nexslice -l app=oai-nssf | grep -i "slice\|selection"

# Vérifier que les DNNs correspondent
kubectl logs -n nexslice -l app=oai-smf | grep -i "dnn\|oai"
```

---

## 8. Arrêt et Nettoyage

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
