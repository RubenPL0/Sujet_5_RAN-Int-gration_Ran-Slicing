# UERANSIM solution

<p align="justify">
Afin de déployer cette solution, déplacez-vous dans le répertoire de travail :
</p>

```bash
cd ./Sujet_5_RAN-Int-gration_Ran-Slicing/Ueransim-5G/scripts
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

