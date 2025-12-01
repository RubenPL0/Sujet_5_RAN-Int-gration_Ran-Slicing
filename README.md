# Projet 5: RAN Slicing


# Sommaire du Projet

1. [Prise en main](#prise-en-main)
2. [État de l'Art : RAN Slicing](#état-de-lart--ran-slicing)
3. [Références](#références)
4. [UERANSIM solution](#ueransim-solution)
5. [Integration ORANSlice + NexSlice Core 5G](#integration-oranslice--nexslice-core-5g)
6. [Conclusion du projet](#conclusion-du-projet)

> Avant d'implémenter une de nos solutions, veuillez vous assurer d'avoir implémenté le coeur de réseau 5G [Nexslice](https://github.com/AIDY-F2N/NexSlice/tree/k3s) sous k3s.

# Prise en main

## Obtenir le projet:

```bash
git clone https://github.com/RubenPL0/Sujet_5_RAN-Int-gration_Ran-Slicing.git

```

**Attention**, Vous devez être placé dans le dossier Nexslice.

Merci de Suivre les readme dans chaque dossier pour le deploiement de la solution.


## Structure du projet

```bash 
.
├── ORANSLICE-Intégration
│   ├── README.md
│   ├── docs
│   ├── k3s-deploy-oranslice/
│   ├── scripts/
│   └── tests/
└── Ueransim-5G
    ├── README.md
    ├── docs/
    ├── k3s-deploy-ueransim/
    └── scripts/
```

Les fichiers README décrivent comment déployer les deux solutions pour NexSlice.

Les dossiers `docs/` regroupent les documents qui constituent le README.

Les dossiers `k3s-deploy-*` contiennent les fichiers de configuration de ORANSlice et UERANSIM.

Les dossiers `scripts/` contiennent les scripts de tests et d'installation.


## Observation 

## Comparaison Baseline vs Solution

| Aspect | NexSlice seul | NexSlice + ORANSlice |
|--------|---------------|----------------------|
| Slicing Core | ok | ok |
| Slicing RAN | non (statique) | ok (dynamique) |
| Allocation PRBs par slice | non | ok |
| Association UE-Slice au MAC | non | ok |

Pour voir les scripts en action, merci de regarder la vidéo `Résultat.mp4` dans le dossier.

## Analyse

    L'analyse est faite dans les README des dossiers Oranslice-Intégration et Ueransim 


---

# État de l'Art : RAN Slicing

## 1. Introduction et contexte du projet
<p align="justify">
Dans le cadre du cours « Infrastructure intelligente logicielle des Réseaux mobiles », nous employons la solution NexSlice qui gère le slicing réseau depuis le cœur 5G.
</p>

<p align="justify">
Actuellement, le RAN alloue ses ressources de manière statique, indépendamment des slices. En pratique, le slicing RAN et le slicing Core doivent être coordonnés pour assurer une QoS de bout en bout dynamique.
</p>

<p align="justify">
L'objectif est d'associer un équipement utilisateur (UE) à une slice et d'allouer des ressources radios selon la slice, en s'inspirant notamment de l'approche O-RAN pour le contrôle de cette répartition.
</p>

---

## 2. Formulation de la problématique technique

<p align="justify">
La problématique centrale de ce projet est l'allocation et la gestion optimisées des ressources radio au sein d'un réseau découpé en <strong>slices</strong>.
</p>

<p align="justify">
Ainsi, nous nous posons la question suivante :
</p>

> Comment garantir une distribution des ressources qui soit à la fois adaptative aux besoins fluctuants des utilisateurs et rigoureusement conforme aux standards de service (latence, débit, fiabilité) propres à chaque catégorie de *slice* (eMBB, URLLC, mMTC), avec d'autres mots, comment répartir le trafic selon chaque type d'utilisation ?

<p align="justify">
Également, comment intégrer ce contrôle du RAN avec un cœur de réseau déjà slicé pour assurer une performance de bout en bout cohérente ?
</p>

---

## 3. Analyse de l'existant

<p align="justify">
Cette section a pour but de disséquer l'écosystème du RAN Slicing, depuis ses fondations théoriques jusqu'à ses implémentations commerciales. L'objectif n'est pas seulement de cataloguer les technologies, mais de comprendre leurs interdépendances, les compromis qu'elles imposent et les tendances qu'elles dessinent pour l'avenir des réseaux mobiles.
</p>

### 3.1 Approches fondamentales et théoriques

<p align="justify">
Cette sous-section établit les bases conceptuelles et normatives du RAN Slicing. Elle est essentielle car elle définit le langage commun et le cadre sur lequel reposent toutes les implémentations pratiques.
</p>

#### 3.1.1 Principes du **Network Slicing**

<p align="justify"> 
Le concept de <strong>network slicing</strong> constitue une avancée majeure dans l’architecture des réseaux mobiles. Il permet de créer des réseaux virtuels indépendants, chacun optimisé pour un service ou un usage spécifique, tout en partageant la même infrastructure physique [<a href="https://ieeexplore.ieee.org/document/7926923">IEEE Network Slicing survey</a>].
</p>

<p align="justify"> 
Chaque <strong>slice</strong> correspond à une composition de bout en bout (E2E) : elle intègre le réseau d’accès radio (RAN), le cœur de réseau (Core Network) et le réseau de transport. <br/>
L’objectif est de fournir un service personnalisé, qu’il s’agisse d’un usage grand public (eMBB), d’applications industrielles critiques (URLLC) ou de communications massives pour objets connectés (mMTC) [<a href="https://www.etsi.org/deliver/etsi_ts/123500_123599/123501/17.05.00_60/ts_123501v170500p.pdf">ETSI - 3GPP TS 123 501</a>]. </p>

Ci-dessous une représentation :

<p align="center">
<img width="550" height="567" alt="image" src="https://github.com/user-attachments/assets/945fb7b6-4dd4-47c6-b1f8-92958a3851ca" />
</p>

<p align="center">
  <em>Source : <a href="https://www.researchgate.net/figure/Network-Slicing-in-5G_fig2_385321905">ResearchGate.net</a></em>
</p>


<p align="justify">
Le 3rd Generation Partnership Project (3GPP), en tant qu'organisme de standardisation central, a normalisé cette technologie. L'évolution de ses spécifications techniques illustre la maturation progressive du concept :
</p>

- **Release 15** a posé les fondations du *network slicing*. La spécification technique (TS) 23.501 a défini l'architecture système 5G incluant nativement le slicing, tandis que la TS 22.261 a spécifié les exigences pour la provision des slices, l'association des équipements utilisateurs (UE) à ces dernières, et les mécanismes d'isolation de performance de base [<a href="https://www.3gpp.org/ftp/Specs/archive/23_series/23.501/">3GPP TS 23.501</a>].

- **Release 17 et 18** ont marqué une étape vers la maturité opérationnelle et la monétisation, en introduisant des mécanismes de contrôle en boucle fermée (*closed loop*) pour supporter dynamiquement de multiples exigences de contrats de niveau de service (SLA) et en se concentrant sur l'ouverture de l'écosystème [<a href="https://www.3gpp.org/ftp/Specs/archive/23_series/23.501/">3GPP TS 23.501</a>].

<p align="justify">
Pour orchestrer ce système, le 3GPP a défini une architecture de gestion de service hiérarchique [<a href="https://www.3gpp.org/ftp/Specs/archive/23_series/23.501/">3GPP TS 23.501</a>], reposant sur trois fonctions logiques principales :
</p>

1. **Communication Service Management Function (CSMF)** : traduit les besoins métiers en exigences de service de communication formelles.
2. **Network Slice Management Function (NSMF)** : gère le cycle de vie complet d'une instance de slice réseau (NSI) et la décompose en exigences techniques pour les sous-réseaux.
3. **Network Slice Subnet Management Function (NSSMF)** : opère au niveau d'un domaine technologique spécifique (RAN, Cœur, Transport) pour configurer et gérer les ressources qui lui sont assignées [<a href="https://www.3gpp.org/ftp/Specs/archive/23_series/23.501/">3GPP TS 23.501</a>].

#### 3.1.2 Association des UEs aux slices : le rôle du NSSAI

<p align="justify">
Un mécanisme fondamental du <strong>network slicing</strong> est la capacité pour le réseau d'associer un équipement utilisateur (UE) à une ou plusieurs slices spécifiques. Le 3GPP a standardisé ce processus autour de l'identifiant <strong>NSSAI (Network Slice Selection Assistance Information)</strong> [<a href="https://www.3gpp.org/ftp/Specs/archive/23_series/23.501/">3GPP TS 23.501</a>].
</p>

<p align="center">
<img width="428" height="261" alt="image" src="https://github.com/user-attachments/assets/c1e62140-317f-499f-bdee-b30382e286d0" />
</p>

<p align="center">
  <em>Source : <a href="https://www.tech-invite.com/3m23/toc/tinv-3gpp-23-003_zi.html">Tech-invite.com</a></em>
</p>

<p align="justify">
Le NSSAI est une collection d'un ou plusieurs <strong>S-NSSAI (Single-NSSAI)</strong>, qui identifient chacun une slice unique. Un S-NSSAI est composé de deux parties :
</p>

1. **SST (Slice/Service Type)** : un champ standardisé qui définit le type de service (SST = 1 pour eMBB, SST = 2 pour URLLC, SST = 3 pour mMTC).
2. **SD (Slice Differentiator)** : un champ optionnel qui permet de différencier plusieurs slices du même type.

<p align="justify">
Lors de la procédure d'enregistrement, l'UE inclut un NSSAI demandé. La fonction AMF du cœur de réseau vérifie les droits de l'abonné et détermine le « NSSAI autorisé » (`Allowed NSSAI`) pour cet UE, qui est ensuite communiqué à l'UE et au RAN. Dès lors, le réseau sait à quelle(s) slice(s) l'UE est associé et peut allouer les ressources correspondantes [<a href="https://www.3gpp.org/ftp/Specs/archive/23_series/23.501/">3GPP TS 23.501</a>].
</p>

#### 3.1.3 Coordination RAN–Cœur pour le slicing de bout en bout

<p align="justify">
Comme le souligne la problématique du projet, le slicing du cœur de réseau seul est insuffisant. Pour qu'une slice délivre les garanties de performance promises (QoS), elle doit être gérée de manière cohérente de bout en bout (E2E). <br/><br/>
	
Un orchestrateur de service de bout en bout, souvent appelé <strong>SMO (Service Management and Orchestration)</strong>, est nécessaire pour automatiser la création, la gestion et la supervision des slices sur tous les domaines (RAN, transport, cœur) [<a href="https://www.cisa.gov/sites/default/files/2024-08/ESF_5G_NETWORK_SLICING-SECURITY_CONSIDERATIONS_FOR_DESIGN%2CDEPLOYMENT%2CAND_MAINTENANCE_FINAL_508.pdf)">cisaSlicingSecurity</a>].
</p>

#### 3.1.4 Technologies fondamentales : NFV et SDN

<p align="justify">
L'agilité requise par le <strong>network slicing</strong> est rendue possible par deux technologies transformatrices :
</p>

- **Network Function Virtualization (NFV)** : découple les fonctions réseau du matériel spécialisé en les implémentant sous forme de logiciels (VNF) s'exécutant sur des serveurs standards. Dans le RAN, cela permet de décomposer la station de base en entités logicielles (vDU, vCU) flexibles.
- **Software-Defined Networking (SDN)** : sépare le plan de contrôle (décision) du plan de données (acheminement). Un contrôleur SDN programmable centralise l'intelligence et pilote dynamiquement l'allocation des ressources radio (RB) aux différentes slices.

<p align="justify">
La synergie entre NFV (qui fournit les briques logicielles) et SDN (qui fournit l'architecte programmable) est la clé de voûte du slicing dynamique [<a href="https://ieeexplore.ieee.org/document/7926923">IEEE Network Slicing</a>].
</p>

#### 3.1.5 Isolation des ressources

<p align="justify">
L'isolation garantit que les performances d'une slice ne sont pas affectées par les autres. Dans le RAN, deux approches s'opposent :
</p>

<p align="center">
<img width="650" height="457" alt="image" src="https://github.com/user-attachments/assets/5c34e1ea-d4ab-4c62-a67a-00503955dd11" />
</p>

<p align="center">
  <em>Source : <a href="https://www.researchgate.net/figure/Soft-hard-and-hybrid-slicing-in-transport-networks_fig8_356802315">ResearchGate.net</a></em>
</p>


- **_Hard Slicing_ (découpage dur)** : repose sur une partition statique et rigoureuse des ressources. Elle offre une **isolation quasi parfaite** et des performances prédictibles, mais au prix d'une **inefficacité potentielle** si les ressources allouées ne sont pas pleinement utilisées.

- **_Soft Slicing_ (découpage doux)** : met en œuvre un partage dynamique et opportuniste des ressources. Elle maximise l'efficacité spectrale grâce au multiplexage, mais rend la garantie de SLAs stricts plus complexe en raison du risque d'interférence inter-slice [<a href="https://ieeexplore.ieee.org/document/9860789">IEEE - Hard and Soft Slicing DRL</a>].

<p align="justify">
Des approches <strong>hybrides</strong> émergent comme des solutions pragmatiques, combinant une base de ressources garanties (hard) avec un pool de ressources partagées (soft) [<a href="https://ieeexplore.ieee.org/document/9860789">IEEE - Hard and Soft Slicing DRL</a>, <a href="https://arxiv.org/pdf/2108.02346">Arxiv - Slicing</a>].
</p>


---

### 3.2 Analyse des solutions technologiques clés

<p align="justify">
Cette sous-section examine les mécanismes techniques spécifiques qui concrétisent les concepts théoriques pour les trois grandes catégories de services 5G.
</p>

#### 3.2.1 L'approche O-RAN et le contrôle intelligent du slicing

<p align="justify"> L’Open RAN est une approche qui transforme profondément les réseaux d’accès radio en remplaçant les équipements fermés et propriétaires par une architecture ouverte, modulaire et interopérable. Elle permet à différents constructeurs de fournir des éléments du RAN qui peuvent fonctionner ensemble grâce à des interfaces standardisées. Cette ouverture facilite l’innovation, la flexibilité et l’intégration de fonctions intelligentes telles que l’optimisation dynamique des ressources ou le slicing radio. [<a href="https://www.o-ran.org/">ORAN Alliance</a>]
</p>

<p align="center">
  <img width="500" height="556" alt="image" src="https://github.com/user-attachments/assets/0234a34e-e6d2-4dfc-8323-2b63b01ae459" />
</p>

<p align="center">
  <em>Source : <a href="https://es.mathworks.com/discovery/o-ran.html">MathWorks_ORAN</a></em>
</p>

<p align="justify">
De plus, l'architecture <strong>Open RAN (O-RAN)</strong> vise à introduire l'ouverture, la désagrégation et l'intelligence dans le RAN. Au cœur de l'O-RAN se trouve le <strong>RAN Intelligent Controller (RIC)</strong>, un composant logiciel qui permet un contrôle avancé et programmable du RAN, essentiel pour la gestion dynamique du slicing. Le RIC est divisé en deux entités :
</p>

1. **Non-Real-Time RIC (Non-RT RIC)** : opérant sur une échelle de temps > 1 s, il est responsable de la définition des politiques globales via des applications appelées **rApps**, qui peuvent s'appuyer sur l'IA/ML pour l'optimisation à long terme.
2. **Near-Real-Time RIC (Near-RT RIC)** : opérant en temps quasi réel (10 ms à 1 s), il héberge des **xApps** qui reçoivent les politiques du Non-RT RIC (via l'interface A1) et les appliquent en contrôlant directement les fonctions du RAN (via l'interface E2) pour ajuster dynamiquement la répartition des ressources [<a href="https://fr.scribd.com/document/761828555/O-RAN-WG1-Slicing-Architecture-R003-v13-00">ORAN Alliance - WG1.Slicing Architecture R003 v13.00</a>].

<p align="justify">
Cette architecture en boucle fermée correspond précisément à l'objectif du projet de « contrôler la répartition des ressources radio ». Le projet <strong>ORANSlice</strong>, mentionné dans les références, est une implémentation open source de ces principes, démontrant la faisabilité du contrôle du slicing via une xApp [<a href="https://ece.northeastern.edu/wineslab/papers/Cheng2024ORANSlice.pdf">Cheng2024ORANSlice</a>].
</p>


#### 3.2.2 Allocation de ressources pour l'eMBB (**Enhanced Mobile Broadband**)

<p align="justify">
L'objectif est de maximiser le débit. Les techniques incluent l'ordonnancement sensible à la qualité du canal et l'allocation de larges bandes passantes. L'apprentissage par renforcement profond (DRL) est de plus en plus étudié pour permettre au système d'apprendre dynamiquement des politiques d'allocation optimales.
</p>

#### 3.2.3 Mécanismes de garantie pour l'URLLC (*Ultra-Reliable and Low-Latency Communication*)

<p align="justify">
Les objectifs sont une latence de l'ordre de la milliseconde et une fiabilité supérieure à 99,999 %, par exemple on utilise ce type de service pour des opérations où on n'a pas le droit à l'erreur: retransmission en direct, chirurgie à distance etc. <br/>
<br/>
Les techniques fondamentales incluent notamment :
</p>

- **_Mini-slot based transmission_** : utilisation d'intervalles de temps de transmission très courts pour réduire la latence de l'interface radio [<a href="https://ieeexplore.ieee.org/abstract/document/9040905">Coexistence of eMBB and URLLC in 5G New Radio</a>].

- **_Punctured Scheduling_ (ordonnancement par préemption)** : un paquet URLLC urgent peut préempter, c'est-à-dire utiliser les ressources déjà allouées à une transmission eMBB moins prioritaire, garantissant une latence minimale pour l'URLLC au détriment de la performance de l'eMBB [<a href="https://ieeexplore.ieee.org/abstract/document/9040905">Coexistence of eMBB and URLLC in 5G New Radio</a>].

- **Planification à deux niveaux (*Two-Level MAC Scheduling*)** : un ordonnanceur *inter-slice* donne une priorité absolue à la slice URLLC, tandis que des ordonnanceurs *intra-slice* gèrent les UEs au sein de chaque slice [<a href="https://www.mdpi.com/1424-8220/22/9/3495"> Two Tier Slicing Resource Allocation Algorithm - DRL </a>].

- **Edge computing** : délocalisation des fonctions réseau et applicatives en périphérie pour minimiser le temps de transit des données [<a href="https://www.3gpp.org/technologies/urlcc-2022">3GPP URLLC</a>].

#### 3.2.4 Stratégies de gestion pour le mMTC (*Massive Machine Type Communications*)
<p align="justify">
Le défi est de gérer un très grand nombre de connexions simultanées.<br/><br/>

Les stratégies se concentrent sur :
</p>

- **Optimisation de la procédure d'accès aléatoire (RACH)** : pour éviter la congestion lors des accès massifs, des approches basées sur l'IA permettent d'allouer dynamiquement les ressources de contrôle [<a href="https://www.techedgewireless.com/post/5g-nr-rach-procedure-in-detail">Tech Edge Wireless - 5G-NR RACH</a>].

- **Coexistence par priorisation des ressources** : la slice mMTC est souvent traitée avec la plus faible priorité, n'utilisant que les ressources résiduelles après l'allocation pour l'URLLC et l'eMBB.
- **Gestion de la sécurité et de l'isolation** : l'isolation stricte des slices mMTC peut par exemple être utilisée pour contenir les attaques (ex : DDoS) et ainsi empêcher leur propagation vers des slices plus critiques.

#### 3.2.5 Tableau comparatif des mécanismes d'allocation de ressources
<p align="justify">
Le tableau ci-dessous synthétise les principales techniques d'allocation de ressources.
</p>

| Technique                | Slice cible | Principe de fonctionnement                                                                                            | Avantage principal                                                       | Inconvénient / compromis                                                                     | Complexité       | Sources                |
| ------------------------ | ----------- | --------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------ | -------------------------------------------------------------------------------------------- | ---------------- | ---------------------- |
| Punctured Scheduling     | URLLC       | Préemption en temps réel des ressources allouées à l'eMBB pour transmettre des paquets URLLC urgents.                 | Garantie de latence ultra-faible pour l'URLLC.                           | Dégradation de la performance (pertes, débit) pour la slice eMBB préemptée.                  | Élevée           | [IEEE](https://ieeexplore.ieee.org/abstract/document/9040905  )|
| Two-Level MAC Scheduling | URLLC, mMTC | Ordonnanceur hiérarchique : 1) inter-slice (priorise les slices) ; 2) intra-slice (gère les UEs au sein de la slice). | Isolation forte et priorisation claire des services critiques (URLLC).   | Moins d'efficacité spectrale globale car le partage opportuniste est limité par la priorité. | Moyenne à élevée | [MDPI](https://www.mdpi.com/1424-8220/22/9/3495) |
| DRL-based Allocation     | eMBB, URLLC | Utilisation d'agents d'apprentissage par renforcement pour apprendre une politique d'allocation optimale.             | Adaptation dynamique à des conditions de trafic et de canal complexes.   | Phase d'apprentissage initiale potentiellement sous-optimale ; complexité du modèle.         | Très élevée      | [IEEE](https://ieeexplore.ieee.org/abstract/document/9040905  )|  |
| RACH Optimization        | mMTC        | Allocation dynamique des ressources de contrôle (PDCCH, préambules) pour gérer les pics d'accès concurrents.          | Réduction des collisions et de la congestion lors des accès massifs.     | Ne concerne que la phase d'accès, pas la transmission de données.                            | Moyenne          | [Tech Edge Wireless - 5G-NR RACH](https://www.techedgewireless.com/post/5g-nr-rach-procedure-in-detail)             |

---

### 3.3 État de l'art des brevets et solutions commerciales

<p align="justify">
Cette partie ancre l'analyse dans la réalité du marché, en examinant comment les concepts théoriques sont transformés en produits commercialisables.
</p>

#### 3.3.1 Solutions 

**ORANSlice (Wineslab / Northeastern University)**

ORANSlice est un framework open source de bout en bout pour le slicing 5G conforme à l'architecture O-RAN. Développé par le laboratoire WiNES de Northeastern University et présenté à ACM MobiCom 2024, il étend la pile protocolaire OpenAirInterface (OAI) pour supporter le slicing au niveau RAN. Ses principales caractéristiques sont :
- Extension de la couche MAC pour inclure un ordonnanceur à deux niveaux (*slice-aware scheduling*) permettant l'association des sessions PDU aux slices.
- Support du multi-slice pour un même UE via la gestion de sessions PDU multiples.
- Implémentation d'un Service Model E2SM-CCC et d'une xApp pour le contrôle dynamique du slicing via le Near-RT RIC.
- Contrôle des politiques RRM (*Radio Resource Management*) via des ratios min/max configurables pour chaque slice.
- Compatibilité avec les testbeds Arena et X5G, ainsi qu'avec le simulateur RFSim.

Le projet est disponible sur GitHub (https://github.com/wineslab/ORANSlice) et représente une base solide pour l'expérimentation de politiques de répartition des ressources.

**SD-RAN (Open Networking Foundation)**

Le projet SD-RAN de l'ONF développe des composants open source complémentaires aux spécifications de l'O-RAN Alliance. Au cœur du projet se trouve un Near-RT RIC basé sur µONOS, une version cloud-native et microservices du contrôleur SDN ONOS. Les fonctionnalités clés incluent :
- Développement de xApps pour la gestion des slices, incluant l'allocation de PRBs (*Physical Resource Blocks*) par slice.
- Support des Service Models E2SM-KPM (Key Performance Measurement) et E2SM-RC (RAN Control).
- SDKs en Go et Python pour le développement d'applications tierces.
- Intégration avec SD-Core pour une solution mobile 4G/5G complète.

Suite à la fusion de l'ONF avec la Linux Foundation fin 2023, le projet continue sous une nouvelle gouvernance. La version 1.4 a été la première release entièrement open source sous licence Apache 2.0.

**UERANSIM (Simulation du RAN et des UEs)**

UERANSIM est un simulateur open source de l'équipement utilisateur (UE) et du réseau d'accès radio (gNodeB) pour les réseaux 5G SA. Bien qu'il ne constitue pas une solution de slicing RAN à proprement parler, il est essentiel pour la validation expérimentale :
- Simulation des fonctionnalités du gNB (nr-gnb) et de l'UE (nr-ue).
- Support du NSSAI (S-NSSAI avec SST et SD) pour l'association des UEs aux slices.
- Établissement de sessions PDU multiples vers différentes slices.
- Interface TUN pour le tunneling du trafic utilisateur vers l'UPF.

UERANSIM est couramment utilisé en combinaison avec des cœurs de réseau open source comme Open5GS ou Free5GC pour créer des environnements de test complets. Cependant, il ne simule pas complètement la couche physique 5G-NR (simulation via UDP), ce qui limite son réalisme pour l'évaluation des performances radio.

**Tableau récapitulatif des solutions open source**

| Solution  | Développeur             | Composant principal   | Niveau de maturité | Licence     | Intégration slicing                        |
| --------- | ----------------------- | --------------------- | ------------------ | ----------- | ------------------------------------------ |
| ORANSlice | Wineslab / Northeastern | RAN (basé OAI) + xApp | Recherche          | Open source | Ordonnanceur slice-aware, contrôle via RIC |
| SD-RAN    | ONF / Linux Foundation  | Near-RT RIC + xApps   | Pré-commercial     | Apache 2.0  | xApp RAN Slice Management, SDKs            |
| UERANSIM  | Communauté              | Simulateur UE/gNB     | Stable             | Open source | Support NSSAI, sessions PDU multi-slice    |



#### 3.3.2 Analyse du paysage des brevets et innovations de recherche
<p align="justify">
Le paysage de la recherche se concentre sur le dépassement des limites actuelles. Plusieurs axes d'innovation se dégagent :
</p>

- **Ordonnancement sensible au canal à deux niveaux** : des travaux comme le projet RadioSaber ont démontré que rendre l'allocation inter-slice sensible aux conditions de canal peut améliorer le débit global de 17 % à 72 % [Radio Saber - Chen Yongzhou](https://www.usenix.org/system/files/nsdi23-chen-yongzhou.pdf).
- **IA/ML pour une gestion prédictive et autonome** : la recherche de pointe se concentre sur des mécanismes **prédictifs** pour anticiper les conditions futures du canal ou la charge de trafic et ajuster proactivement les ressources, évitant ainsi les violations de SLA. Des solutions comme celle de Microsoft visent même à garantir les SLAs au niveau de chaque **application individuelle** au sein d'une slice.
- **Gestion avancée de l'interférence inter-slice** : la recherche académique développe des modèles analytiques sophistiqués pour modéliser, quantifier et gérer activement l'impact de l'interférence entre les slices.

<p align="justify">
Cette trajectoire d'innovation dessine une vision d'un système <strong>autonome et cognitif</strong>, où l'IA ne se contente plus de réagir mais anticipe les états futurs du réseau.
</p>

---

## 4. Synthèse critique et identification des limites

<p align="justify">
Les approches existantes, bien que performantes dans des contextes génériques, montrent leurs limites pour l'intégration fine entre un cœur de réseau spécifique comme NexSlice et un RAN dynamique.
</p>

<p align="justify">
La plupart des solutions commerciales restent des « boîtes noires » et les approches académiques se concentrent souvent sur un seul aspect (ex : ordonnancement URLLC) sans proposer de cadre d'intégration E2E open source et expérimental. Le projet [ORANSlice](https://openrangym.com/ran-frameworks/oranslice) offre une base, mais son intégration avec un cœur de réseau externe et l'expérimentation de politiques de répartition spécifiques restent des défis ouverts.
</p>

---
## 5. Conclusion : verrous technologiques et justification du projet de R&D

L'analyse de l'état de l'art révèle plusieurs verrous technologiques qui justifient pleinement la pertinence de ce projet de R&D.

### 5.1 Verrous technologiques identifiés

**Intégration RAN-Cœur hétérogène**  
Les solutions existantes (ORANSlice, SD-RAN) sont généralement développées comme des écosystèmes intégrés avec leur propre cœur de réseau (OAI CN, Open5GS, SD-Core). L'interconnexion d'un RAN slicé avec un cœur de réseau externe et propriétaire comme NexSlice reste un défi technique non résolu. Les interfaces de communication entre le SMO/RIC et les fonctions de gestion du cœur (NSMF, NSSMF) manquent de standardisation opérationnelle.

**Contrôle dynamique en boucle fermée**  
Si l'architecture O-RAN définit théoriquement les mécanismes de contrôle via le RIC et les xApps, leur implémentation pratique pour une répartition dynamique des ressources en temps quasi réel reste complexe. Les politiques d'allocation doivent pouvoir s'adapter en continu aux variations de charge et aux conditions du canal, ce qui nécessite des algorithmes sophistiqués encore au stade de la recherche (DRL, prédiction par IA/ML).

**Garantie de SLA multi-slice**  
La coexistence de slices aux exigences contradictoires (maximisation du débit pour l'eMBB vs latence ultra-faible pour l'URLLC) impose des compromis difficiles à optimiser. Les mécanismes comme le *punctured scheduling* dégradent les performances d'une slice pour en favoriser une autre, et les approches hybrides (hard/soft slicing) restent à valider expérimentalement dans des conditions réalistes.

**Isolation et efficacité spectrale**  
Le compromis entre isolation stricte des slices et efficacité d'utilisation des ressources spectrales constitue un verrou fondamental. Une isolation parfaite (hard slicing) gaspille des ressources, tandis qu'un partage opportuniste (soft slicing) expose aux interférences inter-slice et complique la garantie des SLAs.

**Outillage expérimental limité**  
Les simulateurs comme UERANSIM ne modélisent pas complètement la couche physique 5G-NR, limitant la validité des résultats pour les scénarios de performance radio. Les testbeds réels (Arena, X5G) restent peu accessibles et les solutions commerciales sont des « boîtes noires » difficilement exploitables pour la recherche.

### 5.2 Justification et positionnement du projet

Ce projet de R&D se positionne précisément dans les interstices laissés par l'existant. En s'appuyant sur l'approche O-RAN et les principes du contrôle intelligent via xApp, l'objectif est de :

1. **Développer une couche d'intégration** entre le cœur de réseau NexSlice (déjà slicé) et un RAN virtualisé, permettant la propagation cohérente des politiques de slicing de bout en bout.

2. **Implémenter et évaluer des politiques de répartition des ressources** adaptées aux trois catégories de services (eMBB, URLLC, mMTC), en s'inspirant des mécanismes identifiés dans la littérature (ordonnancement à deux niveaux, préemption, mini-slots).

3. **Créer un environnement expérimental reproductible** combinant simulation (UERANSIM, RFSim) et émulation pour valider les approches proposées.

4. **Contribuer à la communauté open source** en documentant les interfaces et protocoles nécessaires à l'interopérabilité RAN-Coeur dans un contexte de slicing dynamique.

Ce projet répond ainsi à un besoin concret : dépasser le slicing statique du RAN pour offrir une gestion coordonnée et dynamique des ressources, alignée avec les promesses de la 5G en matière de qualité de service différenciée.


### 5.3 Approche retenue

Nous avons choisi d'utiliser :

- **ORANSlice** comme gNB car il implémente nativement le RAN slicing au niveau du scheduler MAC, conformément aux principes O-RAN étudiés dans l'état de l'art (section 3.2.1).

- **NexSlice (OAI CN)** comme cœur 5G car il supporte le slicing via NSSF, permet de déployer plusieurs SMF/UPF par slice, et est déjà maîtrisé dans le cadre du cours.

- **RFsimulator** pour la simulation radio, permettant de tester sans équipement matériel.

- **Kubernetes (K3s)** pour l'orchestration, facilitant le déploiement et la gestion des composants.

Cette approche permet de valider le control plane du slicing E2E (enregistrement des UEs, établissement des PDU sessions vers les bons UPFs, configuration des slices au MAC) même si le data plane reste limité par les contraintes du simulateur.

### 5.4 Contributions attendues

| Contribution | Description | Critère de validation |
|--------------|-------------|----------------------|
| Intégration ORANSlice + NexSlice | Connexion fonctionnelle gNB-AMF via interface N2/NGAP | Log "gNB-ORANSlice" dans AMF |
| Configuration multi-slice | 3 slices configurées avec politiques RRM distinctes | Logs MAC scheduler avec 3 Slice id |
| Enregistrement multi-UE | 3 UEs enregistrés sur leurs slices respectives | État 5GMM-REGISTERED pour IMSI 041, 042, 043 |
| Routage par slice | Chaque UE obtient une IP du subnet de son UPF dédié | IP 12.1.1.x, 12.1.2.x, 12.1.3.x |
| Documentation | Scripts de validation et guide de reproduction | README et scripts fonctionnels |

---

# Références 


### Architecture et Standards 3GPP
- [3GPP TS 23.501 — System Architecture](https://www.3gpp.org/ftp/Specs/archive/23_series/23.501/)
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
- [ORANSlice — OpenRanGym](https://openrangym.com/ran-frameworks/oranslice)
- [Cheng et al. — ORANSlice (2024)](https://ece.northeastern.edu/wineslab/papers/Cheng2024ORANSlice.pdf)
- [RadioSaber — Chen Yongzhou (NSDI'23)](https://www.usenix.org/system/files/nsdi23-chen-yongzhou.pdf)

### Coexistence eMBB / URLLC / mMTC
- [IEEE — Coexistence of eMBB and URLLC in 5G NR](https://ieeexplore.ieee.org/abstract/document/9040905)
- [MDPI — Two-Tier Slicing Resource Allocation with DRL](https://www.mdpi.com/1424-8220/22/9/3495)
- [Tech Edge Wireless — 5G NR RACH Procedure](https://www.techedgewireless.com/post/5g-nr-rach-procedure-in-detail)

### Projets Open Source
- [NexSlice (AIDY-F2N) — Branche K3s](https://github.com/AIDY-F2N/NexSlice/tree/k3s)


---
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

### Analyse des tests :

**Résultats des tests séquentiels (sans congestion) :**

| Slice | UE | QoS configurée (Max PRB) | Débit mesuré | Utilisation | Verdict |
|-------|-----|----------------|--------------|-------------|---------|
| eMBB | UE1 | 106 Mbps | **51.91 Mbps** | 48.9% | Conforme |
| URLLC | UE2 | 45 Mbps | **41.01 Mbps** | 91.13% | Conforme |
| mMTC | UE3 | 22 Mbps | **20.04 Mbps** | 91.09% | Conforme |

**Observations importantes :**
- Le slice **eMBB** atteint 48.9% de sa limite, nous expliquerons après pourquoi cela est attendu.
- Le slice **URLLC atteint 91.13%**
- Le slice **eMBB atteint 91.09%**

**Calibration UDP :** Un test UDP de calibration a mesuré la **capacité physique maximale** de la machine à **102.63 Mbps**. Cette valeur représente le débit maximum que peut gérer l'environnement virtualisé en simulation "tout-en-un".

**Le débit TCP eMBB (51.91 Mbps) représente environ 50% de la capacité physique UDP** (102.63 Mbps). Cette différence est normale et attendue car :
- **TCP** utilise un contrôle de congestion conservateur (slow start, congestion avoidance)
- **Retransmissions TCP** : La simulation UERANSIM génère des pertes de paquets qui déclenchent des retransmissions, réduisant le débit effectif
- **Latence CPU** : L'environnement virtualisé introduit de la latence qui impacte particulièrement TCP
- **Overhead protocole** : TCP a plus d'overhead que UDP (accusés de réception, fenêtres de congestion)

**Conclusion partielle :** Les trois slices respectent leurs limites QoS. Les slices URLLC et mMTC atteignent quasiment leur limite, confirmant l'efficacité du Traffic Control sur les UPFs.

---

**Résultats des tests concurrents (saturation réseau) :**

Lorsque les 3 UEs transmettent simultanément pendant 30 secondes, la différenciation par slice devient particulièrement visible :

| Slice | Débit concurrent | Ratio mesuré | Ratio attendu | Verdict |
|-------|------------------|--------------|---------------|---------|
| eMBB | **49.67 Mbps** | - | - | Priorité haute |
| URLLC | **40.91 Mbps** | eMBB/URLLC = **1.21x** | 2.0x | Proche |
| mMTC | **20.06 Mbps** | eMBB/mMTC = **2.48x** | 5.0x | Écart significatif |

**Analyse détaillée :**

Les ratios mesurés (1.21x et 2.48x) s'écartent des ratios théoriques attendus (2.0x et 5.0x). Cette différence s'explique par plusieurs facteurs :

1. **Limitation physique de la machine (102.63 Mbps) :** 
   - Débit total concurrent : 49.67 + 40.91 + 20.06 = **110.64 Mbps**
   - Ce total **dépasse légèrement** la capacité UDP mesurée (102.63 Mbps)
   - Le système est donc en **saturation partielle**

2. **QoS individuelles respectées :**
   - eMBB : 49.67 Mbps < 106 Mbps (limite)
   - URLLC : 40.91 Mbps < 45 Mbps (proche de la limite)
   - mMTC : 20.06 Mbps < 22 Mbps (proche de la limite)

3. **Isolation validée malgré l'écart :**
   - Le slice **mMTC maintient ses 20 Mbps** même en charge → Isolation effective
   - Le slice **eMBB reste prioritaire** (49.67 > 40.91 > 20.06) → Hiérarchie respectée
   - En situation de charge, **eMBB > URLLC > mMTC** est observé comme souhaité

4. **Pourquoi les ratios théoriques ne sont pas atteints :**
   - Les QoS sont configurées pour **106/45/22 Mbps** (ratio d'environ 4.8:2.04:1)
   - Mais la **capacité physique totale** n'est que de **102.63 Mbps**
   - Il est donc **physiquement impossible** d'atteindre les ratios théoriques en saturant tous les slices simultanément
   - Les ratios observés (1.21x et 2.48x) reflètent la **répartition réelle** en fonction de la capacité disponible

**Conclusion des tests concurrents :**
Bien que les ratios théoriques ne soient pas atteints en raison de la **limitation physique de la machine hôte** (102.63 Mbps), les résultats démontrent clairement :
1. **Isolation effective** : Chaque slice reste dans sa limite QoS
2. **Priorisation fonctionnelle** : eMBB > URLLC > mMTC même en charge
3. **Limitation environnement** : La VM limite le débit total disponible



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
Ce script résume les fonctionnalités de la solution RAN Slicing UERANSIM.

## 5. Fichier de configuration
Explication du fichier de configuration utilisé pour définir les limites de QoS.

Pour le visualiser, effectuez la commande :

```bash
cat ./5_rrmPolicy.json
```

Voici un aperçu:

<img width="510" height="600" alt="identifiant unique du slice" src="https://github.com/user-attachments/assets/12ae8858-6cad-4925-b46f-7d9ef9415e7f" />


---

# Integration ORANSlice + NexSlice Core 5G

## Résumé

Ce document decrit l'integration du gNB ORANSlice avec le coeur 5G NexSlice pour demontrer le RAN Slicing avec 3 slices reseau (eMBB, URLLC, mMTC).

### Etat actuel

| Composant | Etat | Details |
|-----------|------|---------|
| Control Plane | Fonctionnel | gNB connecte, UEs enregistres, PDU Sessions etablies |
| Data Plane | Non fonctionnel | Paquets IP ne traversent pas le tunnel GTP-U |

---

## Architecture Déployée
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
    | 12.1.1.X  |         | 12.1.2.X  |         | 12.1.3.X  |
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

### 3. Déploiements UEs

Trois déploiements separes :
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
~./scripts/validate-oranslice.sh
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
| ue-embb.yaml | ~/NexSlice/k8s/ | Déploiement UE eMBB |
| ue-urllc.yaml | ~/NexSlice/k8s/ | Déploiement UE URLLC |
| ue-mmtc.yaml | ~/NexSlice/k8s/ | Déploiement UE mMTC |

---

## Limitations et Solutions Futures

### Limitations

Le data plane ne fonctionne pas avec l'image ORANSlice en mode RFsimulator. C'est une limitation de l'implementation ORANSlice, pas de l'architecture NexSlice.

### Solutions possibles

1. Architecture desagregee OAI (CU-CP + CU-UP + DU)
   - Peut mieux gerer le data plane
   - Plus complexe à deployer

2. Contacter les auteurs ORANSlice
   - Signaler le bug de forwarding SDAP/GTP-U
   - Demander une mise a jour

3. FlexRIC + xApp pour le slicing
   - Alternative au RAN slicing integre
   - Controle dynamique via E2

---

## Conclusion

L'integration ORANSlice + NexSlice :

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

# Conclusion du projet

Au final, ce projet ne s'est pas déroulé comme nous l'avions pensé. Nous avons rencontré des difficultés à trouver une solution fonctionnelle que nos ordinateurs portables pouvaient supporter. Au départ, nous avions prévu de partir sur une solution réelle. Nous nous sommes donc tournés vers ORANSlice, jusqu'à découvrir qu'il faudrait du vrai matériel pour pouvoir tester si le RAN slicing fonctionnait avec cet outil.

Nous avons donc décidé de nous concentrer en parallèle sur un projet plus allégé, marchant avec UERANSIM, afin de simuler le comportement d'un RAN slicing, tout en gardant les principales caractéristiques du fonctionnement :

    Application des politiques QoS sur les UPFs dans chaque slice
    IP Forwarding
    NAT

Les résultats ont été satisfaisants. Nous avons également creusé au maximum ce que l'on pouvait d'ORANSlice afin d'obtenir :

- Une connexion gNB-AMF
- Une connexion des UEs au cœur de réseau
- L'application des politiques de slicing

<p align="justify">

Ce projet nous a permis d'approfondir considérablement nos connaissances sur l'architecture 5G et ses enjeux. Nous avons découvert la complexité des interactions entre les différentes couches du réseau, notamment l'importance cruciale du slicing pour isoler et prioriser les flux de données selon les besoins applicatifs. La gestion dynamique des ressources radio et réseau, bien que théorique dans notre cas, nous a fait prendre conscience des défis réels auxquels font face les opérateurs télécoms aujourd'hui. </p> <p align="justify"> Au-delà des aspects techniques, ce projet nous a appris à adapter nos objectifs face aux contraintes matérielles et à trouver des solutions alternatives pour valider nos concepts. La nécessité de basculer d'une solution complète (ORANSlice) vers une approche simplifiée (UERANSIM) tout en conservant l'essence du slicing nous a permis de développer notre capacité à hiérarchiser les fonctionnalités essentielles et à faire des compromis intelligents. 

</p>

## Points d'amélioration identifiés

Avec plus de temps et de ressources, plusieurs pistes auraient mérité d'être explorées :

1. Améliorer les tests Core Network Slicing :

    Déployer Prometheus + Grafana pour visualiser les métriques en temps réel
    Tester des scénarios de mobilité (handover inter-SMF)
    Implémenter des tests de charge avec davantage d'UEs (10-50 simultanés)
    Mesurer la latence end-to-end en plus du débit

2. Optimiser la configuration actuelle :

    Réduire les QoS à 50/25/10 Mbps pour rester sous la capacité physique (102 Mbps)
    Optimiser les paramètres TCP pour minimiser les retransmissions
    Tester sur une machine plus puissante (8 vCPU, 16 GB RAM)

<p align="justify"> En définitive, même si nous n'avons pas atteint tous nos objectifs initiaux, ce projet représente une expérience formatrice qui nous a confrontés aux réalités du déploiement d'infrastructures télécoms modernes. Les compétences acquises en orchestration Kubernetes, configuration réseau et debugging système nous seront certainement utiles dans nos futurs projets professionnels. </p>

---

**Projet 5: RAN Slicing** | 2025 | Télécom SudParis  
*Auteurs : PRETI--LEVY Ruben, MARTIN Claire, MESMIN Aude*
