# Integration ORANSlice + NexSlice Core 5G

## Resume

Ce document decrit l'integration du gNB ORANSlice avec le coeur 5G NexSlice pour demontrer le RAN Slicing avec 3 slices reseau (eMBB, URLLC, mMTC).

### Etat actuel

| Composant | Etat | Details |
|-----------|------|---------|
| Control Plane | Fonctionnel | gNB connecte, UEs enregistres, PDU Sessions etablies |
| Data Plane | Non fonctionnel | Paquets IP ne traversent pas le tunnel GTP-U |

---

## Architecture Deployee
```
+------------------------------------------------------------------+
|                      NexSlice Core 5G (K3s)                      |
|                                                                  |
|  +-----+  +-----+  +-----+  +-----+  +-----+  +-----+  +-----+  |
|  | NRF |  |NSSF |  | AMF |  | SMF |  | UDM |  | UDR |  |AUSF |  |
|  +-----+  +-----+  +--+--+  +--+--+  +-----+  +-----+  +-----+  |
|                       | N2     | N4                              |
|                       |        |                                 |
|                  +----+--------+--------------------+            |
|                  |         UPF Pool                 |            |
|                  |  +------+ +------+ +------+      |            |
|                  |  | UPF1 | | UPF2 | | UPF3 |      |            |
|                  |  |SST=1 | |SST=2 | |SST=3 |      |            |
|                  |  |12.1.1| |12.1.2| |12.1.3|      |            |
|                  |  +------+ +------+ +------+      |            |
|                  +-------------+--------------------+            |
+--------------------------------|--------------------------------+
                                 | N3 (GTP-U)
                                 |
+--------------------------------|--------------------------------+
|                    ORANSlice gNB                                |
|  +----------------------------------------------------------+   |
|  |                MAC Scheduler avec RAN Slicing            |   |
|  |  +----------------+----------------+----------------+     |   |
|  |  |   Slice 1      |   Slice 2      |   Slice 3      |     |   |
|  |  |   SST=1        |   SST=2        |   SST=3        |     |   |
|  |  |   eMBB         |   URLLC        |   mMTC         |     |   |
|  |  |   40-80% PRBs  |   20-40% PRBs  |   5-30% PRBs   |     |   |
|  |  +----------------+----------------+----------------+     |   |
|  +----------------------------------------------------------+   |
|                               |                                 |
|                          RFsimulator                            |
+-------------------------------|---------------------------------+
                                |
          +---------------------+---------------------+
          |                     |                     |
    +-----+-----+         +-----+-----+         +-----+-----+
    | UE eMBB   |         | UE URLLC  |         | UE mMTC   |
    | IMSI 041  |         | IMSI 042  |         | IMSI 043  |
    | SST=1     |         | SST=2     |         | SST=3     |
    | DNN: oai  |         | DNN: oai2 |         | DNN: oai3 |
    | 12.1.1.2  |         | 12.1.2.2  |         | 12.1.3.2  |
    +-----------+         +-----------+         +-----------+
```

---

## Configuration des Slices

### rrmPolicy.json (RAN Slicing)
```json
{
  "rrmPolicyRatio": [
    {
      "sst": 1,
      "sd": 16777215,
      "dedicated_ratio": 10,
      "min_ratio": 40,
      "max_ratio": 80
    },
    {
      "sst": 2,
      "sd": 16777215,
      "dedicated_ratio": 20,
      "min_ratio": 20,
      "max_ratio": 40
    },
    {
      "sst": 3,
      "sd": 16777215,
      "dedicated_ratio": 5,
      "min_ratio": 5,
      "max_ratio": 30
    }
  ]
}
```

### Correspondance Slice - UPF - Subnet

| Slice | SST | SD | DNN | UPF | Subnet | Ratio PRBs |
|-------|-----|-----|-----|-----|--------|------------|
| eMBB | 1 | 0xFFFFFF | oai | UPF1 | 12.1.1.0/24 | 40-80% |
| URLLC | 2 | 0xFFFFFF | oai2 | UPF2 | 12.1.2.0/24 | 20-40% |
| mMTC | 3 | 0xFFFFFF | oai3 | UPF3 | 12.1.3.0/24 | 5-30% |

---

## Ce qui fonctionne (Control Plane)

### 1. Connexion gNB - AMF (NGAP/SCTP)
```
[GNB_APP] Received NGAP_REGISTER_GNB_CNF: associated AMF 1
[AMF] gNB-ORANSlice Connected (Global Id: 0x1E0000)
```

### 2. Enregistrement des UEs (5GMM)
```
5GMM-REGISTERED | 208950000000041 | eMBB  (SST=1)
5GMM-REGISTERED | 208950000000042 | URLLC (SST=2)
5GMM-REGISTERED | 208950000000043 | mMTC  (SST=3)
```

### 3. Etablissement PDU Sessions

Chaque UE obtient une IP du bon UPF selon son slice :
- UE eMBB : 12.1.1.2/24 (via UPF1)
- UE URLLC : 12.1.2.2/24 (via UPF2)
- UE mMTC : 12.1.3.2/24 (via UPF3)

### 4. Creation Tunnels GTP-U
```
[GTPU] Created tunnel for UE ID 1, teid incoming: xxx, teid outgoing: 8
       to remote IPv4: 10.42.0.133 (UPF1)
[GTPU] Created tunnel for UE ID 2, teid incoming: xxx, teid outgoing: 9
       to remote IPv4: 10.42.0.134 (UPF2)
[GTPU] Created tunnel for UE ID 3, teid incoming: xxx, teid outgoing: 10
       to remote IPv4: 10.42.0.135 (UPF3)
```

### 5. Configuration RAN Slicing
```
+++++++ Configured slices at MAC +++++++
Slice id = 1 [ sst = 1, sd = ffffff ]
Slice id = 2 [ sst = 2, sd = ffffff ]
Slice id = 3 [ sst = 3, sd = ffffff ]
```

### 6. SDAP Layer
```
[GNB_APP] SDAP layer is enabled
```

---

## Ce qui ne fonctionne pas (Data Plane)

### Symptome
```bash
$ ping 12.1.1.1  # depuis UE eMBB
3 packets transmitted, 0 received, 100% packet loss
```

### Analyse du probleme

La chaine de transmission des paquets IP est :
```
UE App - TUN interface - NAS - PDCP - SDAP - RLC - MAC - PHY - RFsim
                                  |
                              GTP-U encap
                                  |
                                 UPF
```

Le probleme se situe entre PDCP/SDAP et GTP-U : les paquets IP ne sont pas encapsules et envoyes vers l'UPF.

### Preuves

1. Interface TUN creee : oaitun_ue1 avec IP 12.1.1.2 [OK]
2. Tunnel GTP cree : TEID configure vers UPF [OK]
3. SDAP active : enable_sdap=1 [OK]
4. Mais : Compteurs UDP du gNB n'augmentent pas lors du ping
5. Et : Interface tun0 de l'UPF ne recoit rien (RX packets = 0)

### Cause probable

L'image ORANSlice est un fork d'OAI modifie pour supporter le RAN Slicing. Ces modifications ont probablement :

1. Casse ou desactive le forwarding des paquets dans la couche SDAP/PDCP
2. Introduit un bug dans le mapping QoS Flow - DRB - GTP tunnel
3. N'ont pas ete testees avec RFsimulator en mode data plane

---

## Configurations Effectuees

### 1. ConfigMap gNB (oranslice-gnb-config)

Parametres cles ajoutes :
```conf
gNBs = (
  {
    gNB_ID = 0x1e000;
    gNB_name = "gNB-ORANSlice";
    enable_sdap = 1;  // Active pour le data plane
    
    plmn_list = ({
      mcc = 208;
      mnc = 95;
      snssaiList = (
        { sst = 1; },  // eMBB
        { sst = 2; },  // URLLC
        { sst = 3; }   // mMTC
      );
    });
    
    amf_ip_address = ({ ipv4 = "oai-amf"; });
  }
);

MACRLCs = ({
  SliceConf = "/oai-ran/etc/rrmPolicy.json";
});
```

### 2. Subscribers MySQL
```sql
-- AuthenticationSubscription
INSERT INTO oai_db.AuthenticationSubscription VALUES
('208950000000041', '5G_AKA', 'key...', ...),  -- eMBB
('208950000000042', '5G_AKA', 'key...', ...),  -- URLLC
('208950000000043', '5G_AKA', 'key...', ...);  -- mMTC

-- SessionManagementSubscriptionData
INSERT INTO oai_db.SessionManagementSubscriptionData VALUES
('208950000000041', '20895', '{"sst":1,"sd":"FFFFFF"}', '{"oai":{...}}'),
('208950000000042', '20895', '{"sst":2,"sd":"FFFFFF"}', '{"oai2":{...}}'),
('208950000000043', '20895', '{"sst":3,"sd":"FFFFFF"}', '{"oai3":{...}}');
```

### 3. Deployments UEs

Trois deployements separes :
- ue-embb-oai : IMSI 041, SST=1, DNN=oai
- ue-urllc-oai : IMSI 042, SST=2, DNN=oai2
- ue-mmtc-oai : IMSI 043, SST=3, DNN=oai3

### 4. Service DNS pour gNB
```yaml
apiVersion: v1
kind: Service
metadata:
  name: oranslice-gnb
  namespace: nexslice
spec:
  selector:
    app: oranslice-gnb
  ports:
    - name: rfsim
      port: 4043
      targetPort: 4043
```

---

## Script de Validation
```bash
~/NexSlice/scripts/validate-oranslice.sh
```

Affiche :
1. Connexion gNB - AMF
2. Etat SDAP
3. Slices configurees
4. UEs enregistres
5. Tunnels GTP
6. Etat des pods
7. IPs des UEs
8. Correspondance Slice - UPF

---

## Commandes de Diagnostic

### Verifier la connexion gNB-AMF
```bash
sudo k3s kubectl logs -n nexslice deployment/oai-amf | grep "gNB-ORANSlice"
```

### Verifier les UEs enregistres
```bash
sudo k3s kubectl logs -n nexslice deployment/oai-amf | grep "5GMM-REGISTERED"
```

### Verifier les slices configurees
```bash
sudo k3s kubectl logs -n nexslice deployment/oranslice-gnb | grep "Slice id"
```

### Verifier SDAP
```bash
sudo k3s kubectl logs -n nexslice deployment/oranslice-gnb | grep -i "sdap"
```

### Verifier les tunnels GTP
```bash
sudo k3s kubectl logs -n nexslice deployment/oranslice-gnb | grep "Created tunnel"
```

### Verifier les IPs des UEs
```bash
sudo k3s kubectl exec -n nexslice deployment/ue-embb-oai -- ip addr show oaitun_ue1
sudo k3s kubectl exec -n nexslice deployment/ue-urllc-oai -- ip addr show oaitun_ue1
sudo k3s kubectl exec -n nexslice deployment/ue-mmtc-oai -- ip addr show oaitun_ue1
```

### Tester le data plane (echec attendu)
```bash
sudo k3s kubectl exec -n nexslice deployment/ue-embb-oai -- ping -c 3 12.1.1.1
```

---

## Fichiers de Configuration

| Fichier | Emplacement | Description |
|---------|-------------|-------------|
| rrmPolicy.json | ConfigMap oranslice-gnb-config | Politique RAN Slicing |
| gnb.conf | ConfigMap oranslice-gnb-config | Config gNB avec enable_sdap |
| ue-embb.yaml | ~/NexSlice/k8s/ | Deployment UE eMBB |
| ue-urllc.yaml | ~/NexSlice/k8s/ | Deployment UE URLLC |
| ue-mmtc.yaml | ~/NexSlice/k8s/ | Deployment UE mMTC |

---

## Limitations et Solutions Futures

### Limitation actuelle

Le data plane ne fonctionne pas avec l'image ORANSlice en mode RFsimulator. C'est une limitation de l'implementation ORANSlice, pas de l'architecture NexSlice.

### Solutions possibles

1. Utiliser OAI officiel sans RAN slicing
   - Image : oaisoftwarealliance/oai-gnb:2025.w18
   - Avantage : Data plane fonctionnel
   - Inconvenient : Pas de RAN slicing

2. Architecture desagregee OAI (CU-CP + CU-UP + DU)
   - Peut mieux gerer le data plane
   - Plus complexe a deployer

3. Contacter les auteurs ORANSlice
   - Signaler le bug de forwarding SDAP/GTP-U
   - Demander une mise a jour

4. FlexRIC + xApp pour le slicing
   - Alternative au RAN slicing integre
   - Controle dynamique via E2

---

## Conclusion

L'integration ORANSlice + NexSlice demontre avec succes :

Control Plane complet :
- Connexion N2 (NGAP) entre gNB et AMF
- Enregistrement 5G des UEs avec leurs slices respectives
- Etablissement des PDU Sessions vers les bons UPFs
- Configuration RAN Slicing avec allocation PRBs par slice
- Creation des tunnels GTP-U N3

Data Plane non fonctionnel :
- Limitation de l'image ORANSlice
- Les paquets IP ne traversent pas la chaine radio simulee

Cette integration prouve la faisabilite architecturale du slicing E2E avec NexSlice, meme si le data plane necessite une correction dans l'implementation ORANSlice.

---

## References

- OAI 5G RAN : https://gitlab.eurecom.fr/oai/openairinterface5g
- OAI 5G Core : https://gitlab.eurecom.fr/oai/cn5g
- ORANSlice : https://github.com/AIDY-F2N/ORANSlice
- 3GPP TS 23.501 - System Architecture : https://www.3gpp.org/DynaReport/23501.htm
- 3GPP TS 38.300 - NR Overall Description : https://www.3gpp.org/DynaReport/38300.htm
