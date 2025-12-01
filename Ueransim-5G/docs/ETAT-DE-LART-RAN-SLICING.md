# État de l'Art : RAN Slicing

## 1. Introduction et contexte du projet
<p align="justify">
Dans le cadre du cours « Infrastructure intelligente logicielle des Réseaux mobiles », nous employons la solution NexSlice qui gère le slicing réseau depuis le cœur 5G.
</p>

<p align="justify">
Concrètement, la partie réseaux d'accès radio (ou RAN) et ses ressources ne sont pas réparties en fonction des besoins des slices, et est statique. Dans la réalité, le slicing RAN est coordonné au slicing core pour offrir une qualité de service et de performance de bout en bout de façon dynamique.
</p>

<p align="justify">
L'objectif est donc de pouvoir associer un équipement utilisateur (UE) à une slice et de pouvoir allouer des ressources radios selon la slice, en s'inspirant notamment de l'approche O-RAN pour le contrôle de cette répartition.
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
Les objectifs sont une latence de l'ordre de la milliseconde et une fiabilité supérieure à 99,999 %, par exemple on utilise ce type de service pour des opérations dont on a le droit à <strong>aucune</strong> erreur: retransmission en direct, chirurgie à distance etc. <br/>
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

4. **Contribuer à la communauté open source** en documentant les interfaces et protocoles nécessaires à l'interopérabilité RAN-Cœur dans un contexte de slicing dynamique.

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