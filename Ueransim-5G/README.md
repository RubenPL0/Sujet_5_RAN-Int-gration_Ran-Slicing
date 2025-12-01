# UERANSIM solution

<p align="justify">
Afin de déployer cette solution, déplacez-vous dans le répertoire de travail :
</p>

```bash
cd ./Sujet_5_RAN-Integration_RAN-Slicing
```

> À noter : Afin que cette solution fonctionne, assurez-vous que vos pods gNB et UEs UERANSIM soient en état "Running". Vérifiez les logs de votre gNB, que votre UE soit bien attaché au reste du réseau. Vérifiez les logs de vos UEs également pour s'assurer qu'ils ont bien obtenu une adresse IP.

<p align="justify">
Vous allez ensuite devoir lancer une série de script dans le but de lancer la simulation de RAN slicing.
</p>

## 1. Script d'installation et Configuration

Lancer le premier script:
```bash
./1_setup_improved_tests.sh
```

Qui permet la configuration des limitations QoS et règles de routage au cas où il y aurait un problème.

Exécution du premier script:


<img width="700" height="800" alt="image" src="https://github.com/user-attachments/assets/8b930ea7-e2e7-43c0-8862-24b29c40978e" />

<p align="justify">
En effet, ce script remet le cluster dans un état cohérent avec ce qu’on attend d’un UPF dans un vrai réseau 5G. Il réactive des mécanismes essentiels comme l’<strong>IP forwarding</strong> et le <strong>NAT</strong>, qui n’existent pas par défaut dans un pod Kubernetes. Cela permet de simuler correctement le comportement d’un UPF réel et de garantir que le trafic des UEs circule normalement à travers le cluster. Autrement dit, le script sert à remettre en place les paramètres réseau indispensables pour que les tests de slicing soient fiables.
</p>

<p align="justify">
Pour ce faire, il réinstalle du NAT pour que les paquets venant des UEs ressortent avec une adresse IP acceptable par le cluster et la passerelle. C’est indispensable, car les UEs utilisent des adresses internes qui ne peuvent pas être routées directement. Le NAT assure leur “traduction” et permet au trafic de circuler normalement entre l’UE et l’extérieur.
</p>

<p align="justify">
Il permet d'imposer une limite de débit via <code>tc</code>, ce qui permet de simuler le partage radio entre slices (eMBB, URLLC, mMTC) directement au niveau des UPFs. L’ensemble est une façon simple mais efficace de rendre visibles les effets du slicing dans un environnement Kubernetes qui, par défaut, ne garantit ni isolation, ni routage cohérent, ni shaping.
</p>

<p align="justify">
Le script ne se contente pas de réparer le comportement réseau des UPFs : il lit aussi le fichier <code>5_rrmPolicy.json</code>, qui contient les limites de ressources attribuées à chaque slice. Ce fichier définit notamment un champ <code>maxPRB</code> pour eMBB, URLLC et mMTC, et le script interprète ces valeurs comme des débits maximums à appliquer. En pratique, cela permet d’ajuster automatiquement la QoS imposée aux UPFs en fonction de la politique de slicing définie.
</p>

--- 
### 1.1 Vérification de l'application des politiques QoS

<p align="justify">
Il est ensuite possible de vérifier que les politiques de QoS ont bien été appliquées aux UPFs pour chaque slice, via la commande (remplacer <numero_upf> par l'upf souhaité) :
</p>
	
```bash
sudo k3s kubectl exec -n nexslice $(sudo k3s kubectl get pods -n nexslice -l app.kubernetes.io/name=oai-upf<numero_upf> -o jsonpath='{.items[0].metadata.name}') -- tc qdisc show dev eth0
```

<img width="800" height="153" alt="image" src="https://github.com/user-attachments/assets/0a480db1-8a2e-4754-9a24-3495b78cd9d7" />

<p align="justify">
Vérifiez que les politiques de QoS ont bien été appliquées à tous vos UPF. Sur cette image, nous avons pris pour exemple les détails de l'UPF2.
</p>

La réponse se lit comme suit:

- TBF = Token Bucket Filter (le limiteur de débit)
- rate 45Mbit = le débit maximum autorisé
- burst 16Kb = tolérance de burst
- lat 50ms = latence maximale induite

---

## 2. Étape de tests

Lancer ensuite le deuxième script:

```bash
./2_Full_Tests.sh
```

<p align="justify">
Ce script automatise entièrement les tests de performance du slicing dans NexSlice. Il identifie les pods UEs et le serveur de trafic, lance plusieurs instances iperf3 et vérifie la connectivité 5G. Il réalise ensuite deux séries de mesures : 
</p>

- Un test séquentiel (un UE à la fois) pour observer le débit isolé de chaque slice
- Un test concurrent où les trois UEs génèrent du trafic en même temps afin d’évaluer l’isolation et le partage des ressources entre eMBB, URLLC et mMTC.

<p align="justify">
Le script calibre aussi la capacité physique de la machine via un test UDP saturant, ce qui permet d’interpréter correctement les performances TCP mesurées. Enfin, il calcule automatiquement les ratios entre les slices et les compare aux objectifs définis dans la politique de slicing.
</p>

Vous pourrez visualiser ci-dessous le résultat:


<img width="500" height="700" alt="image" src="https://github.com/user-attachments/assets/590c442c-5023-4058-a735-9bcbc3674509" />

<img width="600" height="500" alt="image" src="https://github.com/user-attachments/assets/02a54173-88ff-45ec-ade9-7241d0f63713" />

<img width="500" height="700" alt="image" src="https://github.com/user-attachments/assets/d802c1eb-8a53-4bb7-a783-5d67275201c3" />

## 3. Étape de nettoyage
Lancer le troisième script:

```bash
./3_cleanup_iperf3.sh
```

<img width="817" height="319" alt="image" src="https://github.com/user-attachments/assets/572f3e2f-badb-4d22-9c9d-fd1f87ba1808" />


## 4. Démonstration

Lancer le quatrième script:

```bash
./4_demo_final_ran_slicing.sh
```


## 5. Fichier de configuration
Explication du fichier de configuration utilisé pour définir les limites de QoS.

Pour le visualiser et comprendre comment il est construit, effectuer la commande :

```bash
cat ./5_rrmPolicy.json
```

---

# Références

### Projets Open Source
- [ORANSlice (WiNeS Lab)](https://github.com/wineslab/ORANSlice) — Projet gNB RAN Slicing
- [ORANSlice — OpenRanGym](https://openrangym.com/ran-frameworks/oranslice)
- [OpenAirInterface 5G RAN](https://gitlab.eurecom.fr/oai/openairinterface5g) — Stack RAN 5G open source
- [OpenAirInterface 5G Core](https://gitlab.eurecom.fr/oai/cn5g) — Cœur 5G open source
- [NexSlice (AIDY-F2N)](https://github.com/AIDY-F2N/NexSlice/tree/k3s) — Déploiement NexSlice

### Architecture et Standards 3GPP
- [3GPP TS 23.501 — System Architecture](https://www.3gpp.org/ftp/Specs/archive/23_series/23.501/)
- [3GPP TS 38.300 — NR Overall Description](https://www.3gpp.org/DynaReport/38300.htm)
- [ETSI - 3GPP TS 123 501 (v17.05.00)](https://www.etsi.org/deliver/etsi_ts/123500_123599/123501/17.05.00_60/ts_123501v170500p.pdf)

### Network Slicing
- [IEEE — Network Slicing Survey](https://ieeexplore.ieee.org/document/7926923)
- [IEEE — Hard and Soft Slicing with DRL](https://ieeexplore.ieee.org/document/9860789)
- [Arxiv — Network Slicing](https://arxiv.org/pdf/2108.02346)
- [Network Slicing in 5G (ResearchGate)](https://www.researchgate.net/figure/Network-Slicing-in-5G_fig2_385321905)
- [CISA — 5G Network Slicing Security Considerations](https://www.cisa.gov/sites/default/files/2024-08/ESF_5G_NETWORK_SLICING-SECURITY_CONSIDERATIONS_FOR_DESIGN%2CDEPLOYMENT%2CAND_MAINTENANCE_FINAL_508.pdf)

### O-RAN
- [O-RAN Alliance](https://www.o-ran.org/)
- [MathWorks — O-RAN Overview](https://es.mathworks.com/discovery/o-ran.html)
- O-RAN Alliance — WG1 Slicing Architecture R003 v13.00

### ORANSlice et RAN Slicing
- [Cheng et al. — ORANSlice (2024)](https://ece.northeastern.edu/wineslab/papers/Cheng2024ORANSlice.pdf)
- [RadioSaber — Chen Yongzhou (NSDI'23)](https://www.usenix.org/system/files/nsdi23-chen-yongzhou.pdf)

### Coexistence eMBB / URLLC / mMTC
- [IEEE — Coexistence of eMBB and URLLC in 5G NR](https://ieeexplore.ieee.org/abstract/document/9040905)
- [MDPI — Two-Tier Slicing Resource Allocation with DRL](https://www.mdpi.com/1424-8220/22/9/3495)
- [Tech Edge Wireless — 5G NR RACH Procedure](https://www.techedgewireless.com/post/5g-nr-rach-procedure-in-detail)
---

