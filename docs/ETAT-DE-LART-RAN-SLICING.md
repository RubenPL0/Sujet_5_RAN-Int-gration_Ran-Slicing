# État de l'Art : RAN Slicing

**Mesmin Aude, Martin Claire et Preti-Levy Ruben**  
_Fisa 2A_  
Sujet 5 – RAN Slicing  

---

## 1. Introduction et contexte du projet

Dans le cadre du cours « Infrastructure intelligente logicielle des Réseaux mobiles », nous employons la solution NexSlice qui gère le slicing réseau depuis le cœur 5G.

Concrètement, la partie réseaux d'accès radio (ou RAN) et ses ressources ne sont pas réparties en fonction des besoins des slices, et est statique. Dans la réalité, le slicing RAN est coordonné au slicing core pour offrir une qualité de service et de performance de bout en bout de façon dynamique.

L'objectif est donc de pouvoir associer un équipement utilisateur (UE) à une slice et de pouvoir allouer des ressources radios selon la slice, en s'inspirant notamment de l'approche O-RAN pour le contrôle de cette répartition.

---

## 2. Formulation de la problématique technique

La problématique centrale de ce projet est l'allocation et la gestion optimisées des ressources radio au sein d'un réseau découpé en *slices*.

Ainsi, nous nous posons la question suivante :

> Comment garantir une distribution des ressources qui soit à la fois adaptative aux besoins fluctuants des utilisateurs et rigoureusement conforme aux standards de service (latence, débit, fiabilité) propres à chaque catégorie de *slice* (eMBB, URLLC, mMTC), avec d'autres mots, comment répartir le trafic selon chaque type d'utilisation ?

Également, comment intégrer ce contrôle du RAN avec un cœur de réseau déjà *slicé* pour assurer une performance de bout en bout cohérente ?

---

## 3. Analyse de l'existant

Cette section a pour but de disséquer l'écosystème du RAN Slicing, depuis ses fondations théoriques jusqu'à ses implémentations commerciales. L'objectif n'est pas seulement de cataloguer les technologies, mais de comprendre leurs interdépendances, les compromis qu'elles imposent et les tendances qu'elles dessinent pour l'avenir des réseaux mobiles.

### 3.1 Approches fondamentales et théoriques

Cette sous-section établit les bases conceptuelles et normatives du RAN Slicing. Elle est essentielle car elle définit le langage commun et le cadre sur lequel reposent toutes les implémentations pratiques.

#### 3.1.1 Principes du *Network Slicing* selon le 3GPP

Le concept de *network slicing* (découpage de réseau) représente une évolution fondamentale dans l'architecture des réseaux mobiles, permettant la création de multiples réseaux virtuels, logiques et indépendants, superposés à une infrastructure physique commune [foukas2017survey].

Chaque *slice* est définie comme une composition de bout en bout (E2E) de toutes les ressources réseau nécessaires, incluant le réseau d'accès radio (RAN), le réseau cœur (Core Network) et le réseau de transport (Transport Network) dans le but de répondre à un objectif commercial ou à un client spécifique, avec des garanties de performance dédiées [3gppTS23501].

Le 3rd Generation Partnership Project (3GPP), en tant qu'organisme de standardisation central, a normalisé cette technologie. L'évolution de ses spécifications techniques illustre la maturation progressive du concept :

- **Release 15** a posé les fondations du *network slicing*. La spécification technique (TS) 23.501 a défini l'architecture système 5G incluant nativement le slicing, tandis que la TS 22.261 a spécifié les exigences pour la provision des slices, l'association des équipements utilisateurs (UE) à ces dernières, et les mécanismes d'isolation de performance de base [3gppTS23501, 3gppTS22261].
- **Release 17 et 18** ont marqué une étape vers la maturité opérationnelle et la monétisation, en introduisant des mécanismes de contrôle en boucle fermée (*closed loop*) pour supporter dynamiquement de multiples exigences de contrats de niveau de service (SLA) et en se concentrant sur l'ouverture de l'écosystème [3gppTS23501].

Pour orchestrer ce système, le 3GPP a défini une architecture de gestion de service hiérarchique [3gppTS23501], reposant sur trois fonctions logiques principales :

1. **Communication Service Management Function (CSMF)** : traduit les besoins métiers en exigences de service de communication formelles [3gppTS23501].
2. **Network Slice Management Function (NSMF)** : gère le cycle de vie complet d'une instance de slice réseau (NSI) et la décompose en exigences techniques pour les sous-réseaux [3gppTS23501].
3. **Network Slice Subnet Management Function (NSSMF)** : opère au niveau d'un domaine technologique spécifique (RAN, Cœur, Transport) pour configurer et gérer les ressources qui lui sont assignées [3gppTS23501].

#### 3.1.2 Association des UEs aux slices : le rôle du NSSAI

Un mécanisme fondamental du *network slicing* est la capacité pour le réseau d'associer un équipement utilisateur (UE) à une ou plusieurs slices spécifiques. Le 3GPP a standardisé ce processus autour de l'identifiant **NSSAI (Network Slice Selection Assistance Information)** [3gppTS23501].

Le NSSAI est une collection d'un ou plusieurs **S-NSSAI (Single-NSSAI)**, qui identifient chacun une slice unique [3gppTS23501]. Un S-NSSAI est composé de deux parties :

1. **SST (Slice/Service Type)** : un champ standardisé qui définit le type de service (SST = 1 pour eMBB, SST = 2 pour URLLC, SST = 3 pour mMTC) [3gppTS23501].
2. **SD (Slice Differentiator)** : un champ optionnel qui permet de différencier plusieurs slices du même type [3gppTS23501].

Lors de la procédure d'enregistrement, l'UE inclut un NSSAI demandé. La fonction AMF du cœur de réseau vérifie les droits de l'abonné et détermine le « NSSAI autorisé » (`Allowed NSSAI`) pour cet UE, qui est ensuite communiqué à l'UE et au RAN. Dès lors, le réseau sait à quelle(s) slice(s) l'UE est associé et peut allouer les ressources correspondantes [samsungSlicing, 3gppTS23501].

#### 3.1.3 Coordination RAN–Cœur pour le slicing de bout en bout

Comme le souligne la problématique du projet, le slicing du cœur de réseau seul est insuffisant. Pour qu'une slice délivre les garanties de performance promises (QoS), elle doit être gérée de manière cohérente de bout en bout (E2E) [cisaSlicingSecurity]. Un orchestrateur de service de bout en bout, souvent appelé **SMO (Service Management and Orchestration)**, est nécessaire pour automatiser la création, la gestion et la supervision des slices sur tous les domaines (RAN, transport, cœur) [cisaSlicingSecurity].

#### 3.1.4 Technologies fondamentales : NFV et SDN

L'agilité requise par le *network slicing* est rendue possible par deux technologies transformatrices :

- **Network Function Virtualization (NFV)** : découple les fonctions réseau du matériel spécialisé en les implémentant sous forme de logiciels (VNF) s'exécutant sur des serveurs standards. Dans le RAN, cela permet de décomposer la station de base en entités logicielles (vDU, vCU) flexibles [foukas2017survey].
- **Software-Defined Networking (SDN)** : sépare le plan de contrôle (décision) du plan de données (acheminement). Un contrôleur SDN programmable centralise l'intelligence et pilote dynamiquement l'allocation des ressources radio (RB) aux différentes slices [foukas2017survey].

La synergie entre NFV (qui fournit les briques logicielles) et SDN (qui fournit l'architecte programmable) est la clé de voûte du slicing dynamique [foukas2017survey].

#### 3.1.5 Isolation des ressources

L'isolation garantit que les performances d'une slice ne sont pas affectées par les autres. Dans le RAN, deux approches s'opposent :

- **_Hard Slicing_ (découpage dur)** : repose sur une partition statique et rigoureuse des ressources. Elle offre une **isolation quasi parfaite** et des performances prédictibles, mais au prix d'une **inefficacité potentielle** si les ressources allouées ne sont pas pleinement utilisées [hybridSlicingDRL].
- **_Soft Slicing_ (découpage doux)** : met en œuvre un partage dynamique et opportuniste des ressources. Elle maximise l'efficacité spectrale grâce au multiplexage, mais rend la garantie de SLAs stricts plus complexe en raison du risque d'interférence inter-slice [hybridSlicingDRL].

Des approches **hybrides** émergent comme des solutions pragmatiques, combinant une base de ressources garanties (hard) avec un pool de ressources partagées (soft) [hybridSlicingDRL, anand2020puncturing].

---

### 3.2 Analyse des solutions technologiques clés

Cette sous-section examine les mécanismes techniques spécifiques qui concrétisent les concepts théoriques pour les trois grandes catégories de services 5G.

#### 3.2.1 L'approche O-RAN et le contrôle intelligent du slicing

L'architecture **Open RAN (O-RAN)** vise à introduire l'ouverture, la désagrégation et l'intelligence dans le RAN [oranSlicingArch]. Au cœur de l'O-RAN se trouve le **RAN Intelligent Controller (RIC)**, un composant logiciel qui permet un contrôle avancé et programmable du RAN, essentiel pour la gestion dynamique du slicing [oranSlicingArch]. Le RIC est divisé en deux entités [oranSlicingArch] :

1. **Non-Real-Time RIC (Non-RT RIC)** : opérant sur une échelle de temps > 1 s, il est responsable de la définition des politiques globales via des applications appelées **rApps**, qui peuvent s'appuyer sur l'IA/ML pour l'optimisation à long terme [oranSlicingArch].
2. **Near-Real-Time RIC (Near-RT RIC)** : opérant en temps quasi réel (10 ms à 1 s), il héberge des **xApps** qui reçoivent les politiques du Non-RT RIC (via l'interface A1) et les appliquent en contrôlant directement les fonctions du RAN (via l'interface E2) pour ajuster dynamiquement la répartition des ressources [oranSlicingArch].

Cette architecture en boucle fermée correspond précisément à l'objectif du projet de « contrôler la répartition des ressources radio ». Le projet **ORANSlice**, mentionné dans les références, est une implémentation open source de ces principes, démontrant la faisabilité du contrôle du slicing via une xApp [cheng2024oranslice].

#### 3.2.2 Allocation de ressources pour l'eMBB (*Enhanced Mobile Broadband*)

L'objectif est de maximiser le débit. Les techniques incluent l'ordonnancement sensible à la qualité du canal et l'allocation de larges bandes passantes [drlEMBB]. L'apprentissage par renforcement profond (DRL) est de plus en plus étudié pour permettre au système d'apprendre dynamiquement des politiques d'allocation optimales [drlEMBB, cbrEMBB].

#### 3.2.3 Mécanismes de garantie pour l'URLLC (*Ultra-Reliable and Low-Latency Communication*)

Les objectifs sont une latence de l'ordre de la milliseconde et une fiabilité supérieure à 99,999 % [foukas2017survey]. Les techniques fondamentales incluent notamment :

- **_Mini-slot based transmission_** : utilisation d'intervalles de temps de transmission très courts pour réduire la latence de l'interface radio [anand2020puncturing].
- **_Punctured Scheduling_ (ordonnancement par préemption)** : un paquet URLLC urgent peut préempter, c'est-à-dire utiliser les ressources déjà allouées à une transmission eMBB moins prioritaire, garantissant une latence minimale pour l'URLLC au détriment de la performance de l'eMBB [anand2020puncturing].
- **Planification à deux niveaux (*Two-Level MAC Scheduling*)** : un ordonnanceur *inter-slice* donne une priorité absolue à la slice URLLC, tandis que des ordonnanceurs *intra-slice* gèrent les UEs au sein de chaque slice [ksentini2018twolevel].
- **Edge computing** : délocalisation des fonctions réseau et applicatives en périphérie pour minimiser le temps de transit des données [edgeURLLC].

#### 3.2.4 Stratégies de gestion pour le mMTC (*Massive Machine Type Communications*)

Le défi est de gérer un très grand nombre de connexions simultanées [rachmMTC]. Les stratégies se concentrent sur :

- **Optimisation de la procédure d'accès aléatoire (RACH)** : pour éviter la congestion lors des accès massifs, des approches basées sur l'IA permettent d'allouer dynamiquement les ressources de contrôle [rachmMTC].
- **Coexistence par priorisation des ressources** : la slice mMTC est souvent traitée avec la plus faible priorité, n'utilisant que les ressources résiduelles après l'allocation pour l'URLLC et l'eMBB [ksentini2018twolevel].
- **Gestion de la sécurité et de l'isolation** : l'isolation stricte des slices mMTC peut par exemple être utilisée pour contenir les attaques (ex : DDoS) et ainsi empêcher leur propagation vers des slices plus critiques [foukas2017survey, 3gppTS22261, mmtcSecurity].

#### 3.2.5 Tableau comparatif des mécanismes d'allocation de ressources

Le tableau ci-dessous synthétise les principales techniques d'allocation de ressources.

| Technique                | Slice cible | Principe de fonctionnement                                                                                            | Avantage principal                                                       | Inconvénient / compromis                                                                     | Complexité       | Sources                |
| ------------------------ | ----------- | --------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------ | -------------------------------------------------------------------------------------------- | ---------------- | ---------------------- |
| Punctured Scheduling     | URLLC       | Préemption en temps réel des ressources allouées à l'eMBB pour transmettre des paquets URLLC urgents.                 | Garantie de latence ultra-faible pour l'URLLC.                           | Dégradation de la performance (pertes, débit) pour la slice eMBB préemptée.                  | Élevée           | [anand2020puncturing]  |
| Two-Level MAC Scheduling | URLLC, mMTC | Ordonnanceur hiérarchique : 1) inter-slice (priorise les slices) ; 2) intra-slice (gère les UEs au sein de la slice). | Isolation forte et priorisation claire des services critiques (URLLC).   | Moins d'efficacité spectrale globale car le partage opportuniste est limité par la priorité. | Moyenne à élevée | [ksentini2018twolevel] |
| DRL-based Allocation     | eMBB, URLLC | Utilisation d'agents d'apprentissage par renforcement pour apprendre une politique d'allocation optimale.             | Adaptation dynamique à des conditions de trafic et de canal complexes.   | Phase d'apprentissage initiale potentiellement sous-optimale ; complexité du modèle.         | Très élevée      | [drlEMBB, cbrEMBB]     |
| Mini-slot Transmission   | URLLC       | Utilisation de TTI (Transmission Time Interval) plus courts que le slot standard de 1 ms.                             | Réduction directe du temps de transmission, composant clé de la latence. | Augmentation de la charge de signalisation de contrôle (overhead).                           | Moyenne          | [anand2020puncturing]  |
| RACH Optimization        | mMTC        | Allocation dynamique des ressources de contrôle (PDCCH, préambules) pour gérer les pics d'accès concurrents.          | Réduction des collisions et de la congestion lors des accès massifs.     | Ne concerne que la phase d'accès, pas la transmission de données.                            | Moyenne          | [rachmMTC]             |

---

### 3.3 État de l'art des brevets et solutions commerciales

Cette partie ancre l'analyse dans la réalité du marché, en examinant comment les concepts théoriques sont transformés en produits commercialisables.

#### 3.3.1 Solutions open source pour le RAN Slicing

Le tableau ci-dessous compare les principales solutions open source disponibles pour implémenter le RAN slicing :

| Solution | Développeur | Description | RAN Slicing natif | Compatibilité Core 5G | Simulation radio | Licence |
|----------|-------------|-------------|-------------------|----------------------|------------------|---------|
| **ORANSlice** | WinesLab (Northeastern University) | Fork d'OpenAirInterface avec scheduler MAC modifié pour le slicing. Implémente l'allocation de PRBs par slice via rrmPolicy.json. Compatible O-RAN via xApp. | Oui (rrmPolicy) | OAI CN, Free5GC | RFsimulator | Apache 2.0 |
| **OpenAirInterface (OAI)** | OSA (OpenAirInterface Software Alliance) | Stack 5G NR complète (gNB, UE, Core). Support basique du slicing via NSSAI mais pas d'allocation dynamique des PRBs par slice au niveau MAC. | Partiel (NSSAI uniquement) | OAI CN | RFsimulator, USRP | OAI License |
| **srsRAN Project** | SRS (Software Radio Systems) | Stack 4G/5G légère et performante. Support du slicing en développement. Excellente documentation et communauté active. | En développement | srsRAN, Open5GS | ZeroMQ, USRP | AGPL v3 |
| **UERANSIM** | Aligungr | Simulateur UE et gNB 5G SA en pur logiciel. Supporte le NSSAI pour l'association aux slices mais pas d'allocation de ressources radio réelle. | Non (simulateur) | Free5GC, Open5GS, OAI CN | Simulé (pas de PHY) | GPL v3 |
| **FlexRIC** | Mosaic5G / OSA | Contrôleur RIC near-RT compatible O-RAN. Permet le déploiement de xApps pour contrôler dynamiquement le RAN via l'interface E2. | Via xApps | Indépendant (contrôle RAN) | N/A | Apache 2.0 |
| **SD-RAN (ONF)** | Open Networking Foundation | Plateforme O-RAN complète avec µONOS-RIC. Intègre des xApps de référence pour le slicing et le contrôle de mobilité. | Oui (via xApps) | Aether | Simulé | Apache 2.0 |

**Analyse comparative :**

- **ORANSlice** est la solution la plus adaptée à notre projet car elle implémente nativement le RAN slicing au niveau du scheduler MAC avec une politique RRM configurable. Son intégration avec OAI CN (utilisé par NexSlice) est documentée.

- **UERANSIM** est utile pour les tests de control plane (enregistrement, PDU session) mais ne simule pas la couche physique réelle, donc pas d'allocation de PRBs.

- **FlexRIC** et **SD-RAN** offrent une architecture O-RAN complète mais nécessitent une infrastructure plus complexe et sont orientés vers le contrôle dynamique via xApps plutôt que vers l'expérimentation académique.

- **srsRAN** est prometteur mais le support du slicing n'est pas encore mature.

#### 3.3.2 Analyse du paysage des brevets et innovations de recherche

Le paysage de la recherche se concentre sur le dépassement des limites actuelles. Plusieurs axes d'innovation se dégagent :

- **Ordonnancement sensible au canal à deux niveaux** : des travaux comme le projet RadioSaber ont démontré que rendre l'allocation inter-slice sensible aux conditions de canal peut améliorer le débit global de 17 % à 72 % [chen2023radiosaber].
- **IA/ML pour une gestion prédictive et autonome** : la recherche de pointe se concentre sur des mécanismes **prédictifs** pour anticiper les conditions futures du canal ou la charge de trafic et ajuster proactivement les ressources, évitant ainsi les violations de SLA [zipper2023]. Des solutions comme celle de Microsoft visent même à garantir les SLAs au niveau de chaque **application individuelle** au sein d'une slice [zipper2023].
- **Gestion avancée de l'interférence inter-slice** : la recherche académique développe des modèles analytiques sophistiqués pour modéliser, quantifier et gérer activement l'impact de l'interférence entre les slices [hybridSlicingDRL].

Cette trajectoire d'innovation dessine une vision d'un système **autonome et cognitif**, où l'IA ne se contente plus de réagir mais anticipe les états futurs du réseau.

---

## 4. Synthèse critique et identification des limites

Les approches existantes, bien que performantes dans des contextes génériques, montrent leurs limites pour l'intégration fine entre un cœur de réseau spécifique comme NexSlice et un RAN dynamique.

La plupart des solutions commerciales restent des « boîtes noires » et les approches académiques se concentrent souvent sur un seul aspect (ex : ordonnancement URLLC) sans proposer de cadre d'intégration E2E open source et expérimental. Le projet ORANSlice [cheng2024oranslice] offre une base, mais son intégration avec un cœur de réseau externe et l'expérimentation de politiques de répartition spécifiques restent des défis ouverts.

**Limites identifiées dans les solutions existantes :**

| Limite | Description | Impact sur le projet |
|--------|-------------|---------------------|
| Fragmentation RAN/Core | Les solutions traitent séparément le slicing RAN et Core sans intégration E2E documentée | Nécessité de créer notre propre méthode d'intégration |
| Documentation insuffisante | Peu de guides d'intégration ORANSlice + Core 5G externe | Apprentissage par expérimentation |
| Limitations des simulateurs | RFsimulator ne supporte pas parfaitement le forwarding data plane | Validation limitée au control plane |
| Complexité de configuration | Multi-composants à configurer de manière cohérente (DB, gNB, UEs, UPFs) | Risque d'erreurs de configuration |
| Maturité variable | Certaines fonctionnalités sont en développement actif | Bugs potentiels, comportements inattendus |

---

## 5. Conclusion : verrous technologiques et justification du projet de R&D

### 5.1 Verrous technologiques identifiés

L'analyse de l'existant met en évidence plusieurs verrous technologiques majeurs :

**Verrou 1 : Intégration RAN-Core fragmentée**

Les solutions existantes traitent généralement le slicing RAN et le slicing Core de manière indépendante. Les cœurs de réseau open source (OAI CN, Free5GC) implémentent le slicing via les S-NSSAI et le routage vers des UPFs dédiés, mais ne communiquent pas nativement avec un RAN capable d'allouer dynamiquement ses ressources par slice. Cette fragmentation empêche une gestion cohérente de bout en bout.

**Verrou 2 : Absence de plateforme expérimentale E2E open source**

Si des projets comme ORANSlice démontrent la faisabilité du RAN slicing avec un scheduler MAC modifié, leur intégration avec un cœur 5G complet reste peu documentée. Les chercheurs et étudiants manquent d'une plateforme unifiée permettant d'expérimenter le slicing de l'UE jusqu'au Data Network.

**Verrou 3 : Limitations des simulateurs radio**

Les simulateurs comme RFsimulator (OAI) permettent de tester le control plane sans matériel radio, mais présentent des limitations pour le data plane. Le forwarding des paquets IP à travers la chaîne protocolaire simulée (PDCP/SDAP/GTP-U) n'est pas toujours fonctionnel, ce qui complique la validation complète du slicing.

**Verrou 4 : Complexité de la configuration multi-slice**

La mise en place d'un environnement multi-slice nécessite la configuration coordonnée de nombreux composants : subscribers dans la base de données (AuthenticationSubscription, SessionManagementSubscriptionData), politique RRM dans le gNB (rrmPolicy.json), DNNs et UPFs dédiés dans le cœur. Cette complexité freine l'expérimentation.

### 5.2 Justification du projet

Face à ces verrous, notre projet vise à :

1. **Démontrer l'intégration RAN-Core** : Connecter le gNB ORANSlice au cœur 5G NexSlice pour prouver la faisabilité d'une architecture E2E slicée.

2. **Valider l'association UE-Slice** : Configurer trois UEs avec des S-NSSAI distincts (SST=1 eMBB, SST=2 URLLC, SST=3 mMTC) et vérifier leur routage vers les UPFs correspondants.

3. **Expérimenter l'allocation de ressources RAN** : Utiliser le mécanisme rrmPolicy d'ORANSlice pour définir des ratios de PRBs par slice (40-80% eMBB, 20-40% URLLC, 5-30% mMTC).

4. **Documenter une méthode reproductible** : Fournir les configurations, scripts et procédures permettant à d'autres équipes de reproduire l'expérimentation.

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

## 6. Références

[3gppTS23501] 3GPP TS 23.501, "System architecture for the 5G System (5GS)", Release 18.

[3gppTS22261] 3GPP TS 22.261, "Service requirements for the 5G system", Release 18.

[foukas2017survey] X. Foukas et al., "Network Slicing in 5G: Survey and Challenges", IEEE Communications Magazine, 2017.

[cheng2024oranslice] H. Cheng et al., "ORANSlice: An Open-Source 5G Network Slicing Platform for O-RAN", ACM Workshop on Open and AI RAN, 2024. https://arxiv.org/abs/2410.12978

[anand2020puncturing] A. Anand et al., "Joint Scheduling of URLLC and eMBB Traffic in 5G Wireless Networks", IEEE INFOCOM, 2020.

[ksentini2018twolevel] A. Ksentini et al., "Providing Low Latency Guarantees for Slicing-Ready 5G Systems via Two-Level MAC Scheduling", IEEE Network, 2018.

[hybridSlicingDRL] Z. Xiong et al., "Deep Reinforcement Learning for Mobile 5G and Beyond", IEEE Communications Surveys & Tutorials, 2019.

[oranSlicingArch] O-RAN Alliance, "O-RAN Architecture Description", O-RAN.WG1.O-RAN-Architecture-Description, 2023.

[cisaSlicingSecurity] CISA, "5G Network Slicing: Security Considerations for Design, Deployment, and Maintenance", 2023.

[samsungSlicing] Samsung, "Network Slicing: 5G's Transformative Technology", Samsung Technical White Paper, 2020.

[drlEMBB] L. Liang et al., "Deep Reinforcement Learning for Resource Allocation in V2V Communications", IEEE Transactions on Vehicular Technology, 2019.

[cbrEMBB] M. Alsenwi et al., "eMBB-URLLC Resource Slicing: A Risk-Sensitive Approach", IEEE Communications Letters, 2019.

[rachmMTC] L. Liu et al., "Deep Learning Based RACH Congestion Control for mMTC in 5G", IEEE Wireless Communications Letters, 2021.

[edgeURLLC] Y. Mao et al., "A Survey on Mobile Edge Computing", IEEE Communications Surveys & Tutorials, 2017.

[mmtcSecurity] I. Ahmad et al., "5G Security: Analysis of Threats and Solutions", IEEE Communications Standards Magazine, 2019.

[chen2023radiosaber] Y. Chen et al., "RadioSaber: A Resource-Efficient RAN Slicing System", ACM MobiCom, 2023.

[zipper2023] E. Zipper et al., "Guaranteed SLAs for 5G Network Slicing with AI", Microsoft Research, 2023.

---
