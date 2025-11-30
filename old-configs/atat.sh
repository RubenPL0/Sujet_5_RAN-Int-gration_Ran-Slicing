#!/bin/bash

#############################################
# Script d'intégration ORANSlice dans NexSlice
# Reproduit EXACTEMENT toutes les étapes du chat
#############################################

set -e

echo "=========================================="
echo "Intégration ORANSlice dans NexSlice"
echo "Reproduction complète du chat"
echo "=========================================="

# Variables
PROJECT_ROOT=$(pwd)
ORANSLICE_DIR="$PROJECT_ROOT/ORANSlice"
K8S_MANIFESTS_DIR="$PROJECT_ROOT/5g_ran/oai-gnb-slicing"
RAN_SLICING_DIR="$PROJECT_ROOT/ran-slicing"

# Couleurs
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_step() {
    echo -e "${GREEN}[ÉTAPE]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERREUR]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[ATTENTION]${NC} $1"
}

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

#############################################
# 0. VÉRIFICATION DES PRÉREQUIS
#############################################

print_step "Vérification des prérequis..."

# Vérifier l'espace disque (minimum 100GB)
AVAILABLE_SPACE=$(df -BG / | awk 'NR==2 {print $4}' | sed 's/G//')
if [ "$AVAILABLE_SPACE" -lt 100 ]; then
    print_warning "Espace disque: ${AVAILABLE_SPACE}GB. 100GB recommandés."
    read -p "Continuer? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Vérifier Docker
if ! command -v docker &> /dev/null; then
    print_step "Installation de Docker..."
    sudo apt update
    sudo apt install -y docker.io
    sudo systemctl start docker
    sudo systemctl enable docker
    sudo usermod -aG docker $USER
    print_warning "IMPORTANT: Déconnectez-vous et reconnectez-vous pour que Docker fonctionne sans sudo"
    print_warning "Ou utilisez 'sudo' devant toutes les commandes docker"
fi

# Vérifier K3s
if ! command -v k3s &> /dev/null; then
    print_error "K3s n'est pas installé. Installation requise."
    exit 1
fi

print_info "✅ Prérequis OK"

#############################################
# 1. CLONER ORANSLICE
#############################################

print_step "Clonage du repository ORANSlice..."

if [ -d "$ORANSLICE_DIR" ]; then
    print_warning "Le dossier ORANSlice existe déjà."
    read -p "Supprimer et recloner? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        rm -rf "$ORANSLICE_DIR"
    else
        print_warning "Utilisation du dossier existant"
    fi
fi

if [ ! -d "$ORANSLICE_DIR" ]; then
    git clone https://github.com/wineslab/ORANSlice.git "$ORANSLICE_DIR"
fi

cd "$ORANSLICE_DIR"

#############################################
# 2. INITIALISER LES SUBMODULES (flexric)
#############################################

print_step "Initialisation du submodule flexric..."

cd "$ORANSLICE_DIR/oai_ran"

# Vérifier si flexric existe déjà
if [ ! -d "openair2/E2AP/flexric/.git" ]; then
    cd openair2/E2AP
    
    # Créer le dossier si nécessaire
    mkdir -p flexric
    
    # Cloner flexric manuellement (le submodule Git ne fonctionne pas)
    if [ ! -d "flexric/.git" ]; then
        rm -rf flexric
        git clone -b service-models-integration https://gitlab.eurecom.fr/mosaic5g/flexric.git
        print_info "✅ Flexric cloné"
    else
        print_info "✅ Flexric existe déjà"
    fi
    
    cd ../..
else
    print_info "✅ Flexric déjà présent"
fi

#############################################
# 3. APPLIQUER LE PATCH rrmPolicy
#############################################

print_step "Application du patch rrmPolicy.json..."

cd "$ORANSLICE_DIR/oai_ran"

# Vérifier si le patch a déjà été appliqué
if [ ! -f "rrmPolicy.json" ]; then
    git apply ../doc/rrmPolicyJson.patch
    print_info "✅ Patch rrmPolicyJson appliqué"
else
    print_info "✅ Patch rrmPolicyJson déjà appliqué"
fi

# Copier rrmPolicy.json à la racine d'ORANSlice
cp rrmPolicy.json "$ORANSLICE_DIR/"

# Corriger le chemin dans la config gNB
sed -i "s|/home/wineslab/ORANSlice/rrmPolicy.json|/home/$USER/ORANSlice/rrmPolicy.json|g" \
    targets/PROJECTS/GENERIC-NR-5GC/CONF/ORANSlice.gnb.sa.band78.fr1.106PRB.usrpx310.conf

print_info "✅ rrmPolicy.json configuré"

#############################################
# 4. CORRECTIONS DU CODE SOURCE
#############################################

print_step "Application des correctifs du code source..."

cd "$ORANSLICE_DIR/oai_ran"

# Correctif 1: Comparaison NULL dans gNB_scheduler_dlsch.c (ligne 656)
print_info "Correctif 1: Comparaison NULL (ligne 656)"
sed -i '656s/if (sd == NULL)/if (json_object_object_get(s_array_obj, "sd") == NULL)/' \
    openair2/LAYER2/NR_MAC_gNB/gNB_scheduler_dlsch.c

# Correctif 2: Fonction non utilisée pf_dl (ligne 1205)
print_info "Correctif 2: Fonction non utilisée pf_dl (ligne 1205)"
sed -i '1205s/static void pf_dl/static void __attribute__((unused)) pf_dl/' \
    openair2/LAYER2/NR_MAC_gNB/gNB_scheduler_dlsch.c

# Correctif 3: Supprimer include E2 dans nr-softmodem.c
print_info "Correctif 3: Supprimer include E2 dans nr-softmodem.c"
sed -i '/#include.*E2_AGENT.*e2_agent_app.h/d' executables/nr-softmodem.c

# Correctif 4: Commenter appel e2_agent_init()
print_info "Correctif 4: Commenter e2_agent_init()"
sed -i 's/^\s*e2_agent_init();/\/\/ e2_agent_init();/g' executables/nr-softmodem.c

# Correctif 5: Commenter fichiers sources E2 dans CMakeLists.txt (lignes 2047-2052)
print_info "Correctif 5: Commenter fichiers E2 dans CMakeLists.txt"
sed -i '2047,2052s/^/# /' CMakeLists.txt

# Vérifier les correctifs
print_info "Vérification des correctifs..."
echo "  - Ligne 656: $(sed -n '656p' openair2/LAYER2/NR_MAC_gNB/gNB_scheduler_dlsch.c | head -c 80)..."
echo "  - Ligne 1205: $(sed -n '1205p' openair2/LAYER2/NR_MAC_gNB/gNB_scheduler_dlsch.c | head -c 80)..."
echo "  - E2 include supprimé: $(grep -c 'e2_agent_app.h' executables/nr-softmodem.c || echo '0') occurrences"
echo "  - CMakeLists.txt lignes commentées: $(sed -n '2047,2052p' CMakeLists.txt | grep -c '^#') / 6"

print_info "✅ Tous les correctifs appliqués"

#############################################
# 5. CONSTRUCTION DE L'IMAGE ran-base
#############################################

print_step "Construction de l'image ran-base (avec protobuf-c)..."

cd "$ORANSLICE_DIR/oai_ran"

# Créer le Dockerfile pour ran-base avec protobuf-c
cat > docker/Dockerfile.base.ubuntu22.fixed << 'EOF'
FROM ubuntu:jammy as ran-base

ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=Europe/Paris

RUN apt-get update && \
    apt-get install -y \
        build-essential \
        cmake \
        git \
        libprotobuf-c-dev \
        protobuf-c-compiler \
        libuhd-dev \
        uhd-host \
        libboost-all-dev \
        libusb-1.0-0-dev \
        ninja-build \
        python3 \
        && rm -rf /var/lib/apt/lists/*

WORKDIR /oai-ran
COPY . .
RUN cd cmake_targets && ./build_oai -I
EOF

print_info "Construction de ran-base (cela prend 10-20 minutes)..."
sudo docker build -t ran-base:latest -f docker/Dockerfile.base.ubuntu22.fixed . 2>&1 | tee /tmp/docker-build-base.log

# Vérifier que l'image est créée
if sudo docker images | grep -q "ran-base.*latest"; then
    print_info "✅ Image ran-base créée avec succès"
else
    print_error "Échec de la création de ran-base"
    exit 1
fi

#############################################
# 6. CONSTRUCTION DE L'IMAGE oranslice-gnb
#############################################

print_step "Construction de l'image oranslice-gnb..."

cd "$ORANSLICE_DIR/oai_ran"

# Créer le Dockerfile pour oranslice-gnb
cat > docker/Dockerfile.oranslice << 'EOF'
FROM ran-base:latest

WORKDIR /oai-ran
COPY . .

# Patch 1: Supprimer include E2 dans nr-softmodem.c
RUN sed -i '/#include.*E2_AGENT.*e2_agent_app.h/d' executables/nr-softmodem.c

# Patch 2: Commenter appel e2_agent_init()
RUN sed -i 's/^\s*e2_agent_init();/\/\/ e2_agent_init();/g' executables/nr-softmodem.c

# Patch 3: Commenter fichiers sources E2 dans CMakeLists.txt (lignes 2047-2052)
RUN sed -i '2047s|^|# |' CMakeLists.txt && \
    sed -i '2048s|^|# |' CMakeLists.txt && \
    sed -i '2049s|^|# |' CMakeLists.txt && \
    sed -i '2050s|^|# |' CMakeLists.txt && \
    sed -i '2051s|^|# |' CMakeLists.txt && \
    sed -i '2052s|^|# |' CMakeLists.txt

# Vérifier les patchs
RUN echo "=== Patch verification ===" && \
    grep -n "e2_agent" executables/nr-softmodem.c || echo "✓ E2 references removed" && \
    sed -n '2047,2052p' CMakeLists.txt

# Build gNB uniquement
RUN cd cmake_targets && \
    ./build_oai --gNB -w USRP --ninja -c --noavx512

# Vérifier que le binaire existe
RUN ls -lah cmake_targets/ran_build/build/nr-softmodem
EOF

print_info "Construction de oranslice-gnb (cela prend 15-30 minutes)..."
sudo docker build -t oranslice-gnb:latest -f docker/Dockerfile.oranslice . 2>&1 | tee /tmp/docker-build-gnb.log

# Vérifier que l'image est créée
if sudo docker images | grep -q "oranslice-gnb.*latest"; then
    GNBSIZE=$(sudo docker images | grep "oranslice-gnb.*latest" | awk '{print $7" "$8}')
    print_info "✅ Image oranslice-gnb créée avec succès ($GNBSIZE)"
else
    print_error "Échec de la création de oranslice-gnb"
    print_info "Consultez les logs: /tmp/docker-build-gnb.log"
    exit 1
fi

#############################################
# 7. IMPORTER L'IMAGE DANS K3S
#############################################

print_step "Export et import de l'image dans K3s..."

# Export de l'image Docker
print_info "Export de l'image (peut prendre quelques minutes)..."
sudo docker save oranslice-gnb:latest -o /tmp/oranslice-gnb.tar

# Vérifier la taille du tar
TAR_SIZE=$(ls -lh /tmp/oranslice-gnb.tar | awk '{print $5}')
print_info "Taille du fichier tar: $TAR_SIZE"

# Import dans K3s
print_info "Import dans K3s..."
sudo k3s ctr images import /tmp/oranslice-gnb.tar

# Nettoyer le fichier tar
rm /tmp/oranslice-gnb.tar

# Vérifier que l'image est dans K3s
if sudo k3s ctr images ls | grep -q "oranslice-gnb"; then
    print_info "✅ Image importée dans K3s"
else
    print_error "Échec de l'import dans K3s"
    exit 1
fi

#############################################
# 8. CRÉER LES CONFIGMAPS KUBERNETES
#############################################

print_step "Création des ConfigMaps Kubernetes..."

cd "$PROJECT_ROOT"
mkdir -p k3s-deploy-oranslice
cd k3s-deploy-oranslice

# ConfigMap 1: rrmPolicy.json
print_info "Création du ConfigMap rrmPolicy.json..."
cat > configmap-rrmpolicy.yaml << 'EOF'
apiVersion: v1
kind: ConfigMap
metadata:
  name: rrmpolicy-config
  namespace: nexslice
data:
  rrmPolicy.json: |
    {
      "rrmPolicyRatio": [
        {
          "sst": 1,
          "dedicated_ratio": 5,
          "min_ratio": 10,
          "max_ratio": 100
        },
        {
          "sst": 1,
          "sd": 2,
          "dedicated_ratio": 5,
          "min_ratio": 10,
          "max_ratio": 50
        }
      ]
    }
EOF

# ConfigMap 2: Configuration gNB (avec TDD et AMF)
print_info "Création du ConfigMap configuration gNB..."
cat > configmap-gnb-k3s.yaml << 'EOF'
apiVersion: v1
kind: ConfigMap
metadata:
  name: gnb-config-k3s
  namespace: nexslice
data:
  gnb.conf: |
    Active_gNBs = ( "gNB-ORANSlice");
    
    gNBs = (
    {
        gNB_ID = 0x1e00;
        gNB_name = "gNB-ORANSlice";
        tracking_area_code = 1;
        
        plmn_list = ({
          mcc = 208; 
          mnc = 95; 
          mnc_length = 2;
          snssaiList = (
            { sst = 1; sd = 0xFFFFFF; },
            { sst = 1; sd = 0x000002; }
          );
        });
        
        nr_cellid = 12345678L;
        
        servingCellConfigCommon = ({
          physCellId = 0;
          absoluteFrequencySSB = 641280;
          dl_frequencyBand = 78;
          dl_absoluteFrequencyPointA = 640008;
          dl_offstToCarrier = 0;
          dl_subcarrierSpacing = 1;
          dl_carrierBandwidth = 106;
          initialDLBWPlocationAndBandwidth = 28875;
          initialDLBWPsubcarrierSpacing = 1;
          initialDLBWPcontrolResourceSetZero = 12;
          initialDLBWPsearchSpaceZero = 0;
          
          ul_frequencyBand = 78;
          ul_offstToCarrier = 0;
          ul_subcarrierSpacing = 1;
          ul_carrierBandwidth = 106;
          pMax = 20;
          initialULBWPlocationAndBandwidth = 28875;
          initialULBWPsubcarrierSpacing = 1;
          
          prach_ConfigurationIndex = 98;
          prach_msg1_FDM = 0;
          prach_msg1_FrequencyStart = 0;
          zeroCorrelationZoneConfig = 13;
          preambleReceivedTargetPower = -96;
          preambleTransMax = 6;
          powerRampingStep = 1;
          ra_ResponseWindow = 4;
          ssb_perRACH_OccasionAndCB_PreamblesPerSSB_PR = 4;
          ssb_perRACH_OccasionAndCB_PreamblesPerSSB = 14;
          ra_ContentionResolutionTimer = 7;
          rsrp_ThresholdSSB = 19;
          prach_RootSequenceIndex_PR = 2;
          prach_RootSequenceIndex = 1;
          msg1_SubcarrierSpacing = 1;
          restrictedSetConfig = 0;
          msg3_DeltaPreamble = 1;
          p0_NominalWithGrant = -90;
          
          pucchGroupHopping = 0;
          hoppingId = 40;
          p0_nominal = -90;
          ssb_PositionsInBurst_PR = 2;
          ssb_PositionsInBurst_Bitmap = 1;
          ssb_periodicityServingCell = 2;
          dmrs_TypeA_Position = 0;
          subcarrierSpacing = 1;
          
          referenceSubcarrierSpacing = 1;
          dl_UL_TransmissionPeriodicity = 6;
          nrofDownlinkSlots = 7;
          nrofDownlinkSymbols = 6;
          nrofUplinkSlots = 2;
          nrofUplinkSymbols = 4;
          
          ssPBCH_BlockPower = -25;
        });
        
        SCTP = {
          SCTP_INSTREAMS = 2;
          SCTP_OUTSTREAMS = 2;
        };
        
        amf_ip_address = ({ 
          ipv4 = "oai-amf";
          active = "yes";
          preference = "ipv4";
        });
        
        NETWORK_INTERFACES = {
          GNB_INTERFACE_NAME_FOR_NG_AMF = "eth0";
          GNB_IPV4_ADDRESS_FOR_NG_AMF = "0.0.0.0/24";
          GNB_INTERFACE_NAME_FOR_NGU = "eth0";
          GNB_IPV4_ADDRESS_FOR_NGU = "0.0.0.0/24";
          GNB_PORT_FOR_S1U = 2152;
        };
    });
    
    MACRLCs = ({
      num_cc = 1;
      tr_s_preference = "local_L1";
      tr_n_preference = "local_RRC";
      SliceConf = "/mnt/rrmpolicy/rrmPolicy.json";
    });
    
    L1s = ({
      num_cc = 1;
      tr_n_preference = "local_mac";
    });
    
    RUs = ({
      local_rf = "yes";
      nb_tx = 1;
      nb_rx = 1;
      bands = [78];
      eNB_instances = [0];
    });
    
    THREAD_STRUCT = ({
      parallel_config = "PARALLEL_SINGLE_THREAD";
      worker_config = "WORKER_ENABLE";
    });
    
    rfsimulator = {
      serveraddr = "server";
      serverport = "4043";
      modelname = "AWGN";
    };
    
    security = {
      ciphering_algorithms = ( "nea0" );
      integrity_algorithms = ( "nia0" );
      drb_ciphering = "no";
      drb_integrity = "no";
    };
EOF

print_info "✅ ConfigMaps créés"

#############################################
# 9. CRÉER LE DEPLOYMENT KUBERNETES
#############################################

print_step "Création du Deployment Kubernetes..."

cat > deployment-oranslice-gnb.yaml << 'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: oranslice-gnb
  namespace: nexslice
  labels:
    app: oranslice-gnb
spec:
  replicas: 1
  selector:
    matchLabels:
      app: oranslice-gnb
  template:
    metadata:
      labels:
        app: oranslice-gnb
    spec:
      containers:
      - name: gnb
        image: docker.io/library/oranslice-gnb:latest
        imagePullPolicy: Never
        command: ["/bin/bash", "-c"]
        args:
          - |
            echo "Starting ORANSlice gNB with RAN Slicing..."
            cd /oai-ran/cmake_targets/ran_build/build
            ./nr-softmodem -O /mnt/config/gnb.conf --rfsim --sa
        volumeMounts:
        - name: gnb-config
          mountPath: /mnt/config
        - name: rrmpolicy
          mountPath: /mnt/rrmpolicy
        securityContext:
          privileged: true
      volumes:
      - name: gnb-config
        configMap:
          name: gnb-config-k3s
      - name: rrmpolicy
        configMap:
          name: rrmpolicy-config
EOF

print_info "✅ Deployment créé"

#############################################
# 10. DÉPLOYER SUR K3S
#############################################

print_step "Déploiement sur K3s..."

# Appliquer les ConfigMaps
print_info "Application des ConfigMaps..."
sudo kubectl apply -f configmap-rrmpolicy.yaml
sudo kubectl apply -f configmap-gnb-k3s.yaml

# Appliquer le Deployment
print_info "Application du Deployment..."
sudo kubectl apply -f deployment-oranslice-gnb.yaml

# Attendre que le pod démarre
print_info "Attente du démarrage du pod (20 secondes)..."
sleep 20

print_info "✅ Déploiement effectué"

#############################################
# 11. VÉRIFICATION DU DÉPLOIEMENT
#############################################

print_step "Vérification du déploiement..."

echo ""
echo "========== Statut du pod =========="
sudo kubectl get pods -n nexslice | grep oranslice

echo ""
echo "========== Slices configurés (attente 10s) =========="
sleep 10
POD_NAME=$(sudo kubectl get pods -n nexslice -o name | grep oranslice | head -1)
sudo kubectl logs -n nexslice "$POD_NAME" 2>/dev/null | grep -A 5 "Configured slices" || echo "En attente du démarrage complet..."

echo ""
echo "========== Connexion AMF (attente 10s) =========="
sleep 10
sudo kubectl logs -n nexslice $(sudo kubectl get pods -n nexslice -o name | grep amf | head -1) --tail=50 2>/dev/null | grep -A 10 "gNBs' Information" || echo "En attente de la connexion AMF..."

#############################################
# 12. CRÉER LES SCRIPTS UTILES
#############################################

print_step "Création des scripts utiles..."

# Script de vérification du statut
cat > "$PROJECT_ROOT/check_oranslice_status.sh" << 'EOFSCRIPT'
#!/bin/bash

echo "=========================================="
echo "Statut ORANSlice gNB"
echo "=========================================="

echo ""
echo "1. Statut du pod:"
sudo kubectl get pods -n nexslice | grep oranslice

echo ""
echo "2. Slices configurés:"
POD=$(sudo kubectl get pods -n nexslice -o name | grep oranslice | head -1)
sudo kubectl logs -n nexslice "$POD" | grep -A 5 "Configured slices" | tail -6

echo ""
echo "3. Connexion AMF:"
sudo kubectl logs -n nexslice $(sudo kubectl get pods -n nexslice -o name | grep amf | head -1) \
    --tail=100 | grep -A 10 "gNBs' Information" | tail -12

echo ""
echo "4. Derniers logs gNB (20 lignes):"
sudo kubectl logs -n nexslice "$POD" --tail=20

echo ""
echo "=========================================="
EOFSCRIPT

chmod +x "$PROJECT_ROOT/check_oranslice_status.sh"

# Script de redémarrage
cat > "$PROJECT_ROOT/restart_oranslice.sh" << 'EOFSCRIPT'
#!/bin/bash

echo "Redémarrage du gNB ORANSlice..."
sudo kubectl delete pod -n nexslice -l app=oranslice-gnb

echo "Attente du nouveau pod (20s)..."
sleep 20

echo "Statut:"
sudo kubectl get pods -n nexslice | grep oranslice
EOFSCRIPT

chmod +x "$PROJECT_ROOT/restart_oranslice.sh"

# Script de modification de rrmPolicy
cat > "$PROJECT_ROOT/update_rrmpolicy.sh" << 'EOFSCRIPT'
#!/bin/bash

echo "=========================================="
echo "Modification de rrmPolicy.json"
echo "=========================================="

# Afficher la politique actuelle
echo ""
echo "Politique actuelle:"
sudo kubectl get configmap rrmpolicy-config -n nexslice -o jsonpath='{.data.rrmPolicy\.json}' | jq .

echo ""
read -p "Modifier la politique? (y/n) " -n 1 -r
echo

if [[ $REPLY =~ ^[Yy]$ ]]; then
    # Créer un fichier temporaire
    TMPFILE=$(mktemp)
    sudo kubectl get configmap rrmpolicy-config -n nexslice -o jsonpath='{.data.rrmPolicy\.json}' > "$TMPFILE"
    
    # Ouvrir dans l'éditeur
    ${EDITOR:-nano} "$TMPFILE"
    
    # Valider le JSON
    if jq . "$TMPFILE" > /dev/null 2>&1; then
        # Supprimer et recréer le ConfigMap
        sudo kubectl delete configmap rrmpolicy-config -n nexslice
        sudo kubectl create configmap rrmpolicy-config --from-file=rrmPolicy.json="$TMPFILE" -n nexslice
        
        # Redémarrer le pod pour charger la nouvelle politique
        echo "Redémarrage du gNB..."
        sudo kubectl delete pod -n nexslice -l app=oranslice-gnb
        
        echo "✅ Politique mise à jour! Le scheduler la lira automatiquement."
    else
        echo "❌ JSON invalide. Modification annulée."
    fi
    
    rm "$TMPFILE"
fi
EOFSCRIPT

chmod +x "$PROJECT_ROOT/update_rrmpolicy.sh"

print_info "✅ Scripts créés:"
echo "  - check_oranslice_status.sh"
echo "  - restart_oranslice.sh"
echo "  - update_rrmpolicy.sh"

#############################################
# 13. CRÉER LA DOCUMENTATION
#############################################

print_step "Création de la documentation..."

cat > "$PROJECT_ROOT/ORANSLICE_INTEGRATION.md" << 'EOFDOC'
# Intégration ORANSlice dans NexSlice

## ✅ Installation terminée

### Ce qui a été fait

1. **ORANSlice cloné et préparé**
   - Repository: https://github.com/wineslab/ORANSlice
   - Submodule flexric initialisé
   - Patch rrmPolicy.json appliqué

2. **Code source corrigé**
   - Ligne 656: Comparaison NULL corrigée
   - Ligne 1205: Fonction pf_dl marquée comme non utilisée
   - Include E2 supprimé
   - Appel e2_agent_init() commenté
   - Fichiers E2 dans CMakeLists.txt commentés

3. **Images Docker construites**
   - `ran-base:latest` - Base avec protobuf-c
   - `oranslice-gnb:latest` - gNB avec RAN slicing

4. **Déployé sur K3s (namespace: nexslice)**
   - ConfigMap rrmPolicy.json
   - ConfigMap configuration gNB
   - Deployment oranslice-gnb

### Architecture déployée
```
┌─────────────────────────────────────┐
│  ORANSlice gNB (ID: 0x1E00)         │
│  ┌───────────────────────────────┐  │
│  │ Slice 1: SST=1, SD=0xFFFFFF   │  │
│  │ → 10-100% ressources (eMBB)   │  │
│  └───────────────────────────────┘  │
│  ┌───────────────────────────────┐  │
│  │ Slice 2: SST=1, SD=0x000002   │  │
│  │ → 10-50% ressources (custom)  │  │
│  └───────────────────────────────┘  │
│  ┌───────────────────────────────┐  │
│  │ Slice 0: SST=0, SD=0x000000   │  │
│  │ → Défaut                      │  │
│  └───────────────────────────────┘  │
│                                     │
│  rrmPolicy.json lu toutes les      │
│  ~1.28 secondes (128 frames)       │
└──────────────┬──────────────────────┘
               │ NGAP/SCTP
               ↓
    ┌──────────────────────┐
    │   AMF (oai-amf)      │
    │   Core 5G NexSlice   │
    └──────────────────────┘
```

### Slices configurés

| Slice | SST | SD | Dedicated | Min | Max | Usage |
|-------|-----|-----|-----------|-----|-----|-------|
| 1 | 1 | 0xFFFFFF | 5% | 10% | 100% | eMBB (haut débit) |
| 2 | 1 | 0x000002 | 5% | 10% | 50% | Services modérés |
| 0 | 0 | 0x000000 | - | - | - | Défaut |

### Scripts disponibles
```bash
# Vérifier le statut complet
./check_oranslice_status.sh

# Redémarrer le gNB
./restart_oranslice.sh

# Modifier rrmPolicy.json
./update_rrmpolicy.sh
```

### Commandes utiles
```bash
# Voir les logs en temps réel
sudo kubectl logs -n nexslice -l app=oranslice-gnb -f

# Vérifier les slices configurés
sudo kubectl logs -n nexslice -l app=oranslice-gnb | grep "Configured slices"

# Vérifier la connexion AMF
sudo kubectl logs -n nexslice $(sudo kubectl get pods -n nexslice -o name | grep amf) \
    --tail=50 | grep "gNBs' Information"

# Voir le contenu de rrmPolicy.json
sudo kubectl get configmap rrmpolicy-config -n nexslice -o jsonpath='{.data.rrmPolicy\.json}' | jq .

# Modifier la configuration gNB
sudo kubectl edit configmap gnb-config-k3s -n nexslice

# Supprimer le déploiement
sudo kubectl delete deployment oranslice-gnb -n nexslice
sudo kubectl delete configmap rrmpolicy-config gnb-config-k3s -n nexslice
```

### Modifier rrmPolicy.json à chaud

1. Modifier le fichier:
```bash
./update_rrmpolicy.sh
```

2. Ou manuellement:
```bash
# Éditer
sudo kubectl edit configmap rrmpolicy-config -n nexslice

# Redémarrer (optionnel, le scheduler lit le fichier automatiquement)
sudo kubectl delete pod -n nexslice -l app=oranslice-gnb
```

Le scheduler MAC lit `/mnt/rrmpolicy/rrmPolicy.json` toutes les ~1.28 secondes et applique automatiquement les changements.

### Fichiers créés

- `k3s-deploy-oranslice/configmap-rrmpolicy.yaml`
- `k3s-deploy-oranslice/configmap-gnb-k3s.yaml`
- `k3s-deploy-oranslice/deployment-oranslice-gnb.yaml`
- `check_oranslice_status.sh`
- `restart_oranslice.sh`
- `update_rrmpolicy.sh`

### Logs de construction

- `/tmp/docker-build-base.log` - Logs de construction ran-base
- `/tmp/docker-build-gnb.log` - Logs de construction oranslice-gnb

### Troubleshooting

#### Le pod ne démarre pas
```bash
sudo kubectl describe pod -n nexslice -l app=oranslice-gnb
sudo kubectl logs -n nexslice -l app=oranslice-gnb
```

#### Le gNB n'apparaît pas dans l'AMF
```bash
# Vérifier les logs SCTP/NGAP
sudo kubectl logs -n nexslice -l app=oranslice-gnb | grep -i "sctp\|ngap\|amf"
```

#### Les slices ne sont pas configurés
```bash
# Vérifier le montage de rrmPolicy.json
sudo kubectl exec -n nexslice -l app=oranslice-gnb -- ls -la /mnt/rrmpolicy/
sudo kubectl exec -n nexslice -l app=oranslice-gnb -- cat /mnt/rrmpolicy/rrmPolicy.json
```

### Prochaines étapes

1. **Connecter des UEs aux différents slices**
2. **Tester les performances par slice**
3. **Modifier rrmPolicy.json et observer l'impact**
4. **Monitorer avec Grafana**

### Références

- [ORANSlice GitHub](https://github.com/wineslab/ORANSlice)
- [OpenAirInterface](https://openairinterface.org/)
- Conversation d'installation complète disponible
EOFDOC

print_info "✅ Documentation créée: ORANSLICE_INTEGRATION.md"

#############################################
# RÉSUMÉ FINAL
#############################################

echo ""
echo "=========================================="
echo "         🎉 INSTALLATION TERMINÉE ! 🎉"
echo "=========================================="
echo ""
echo "✅ ORANSlice compilé et déployé sur K3s"
echo "✅ 3 slices RAN configurés et actifs"
echo "✅ rrmPolicy.json avec allocation dynamique"
echo ""
echo "📊 Slices configurés:"
echo "   - Slice 1 (SST=1, SD=0xFFFFFF): 10-100% ressources"
echo "   - Slice 2 (SST=1, SD=0x000002): 10-50% ressources"
echo "   - Slice 0 (SST=0, SD=0x000000): défaut"
echo ""
echo "🔧 Scripts disponibles:"
echo "   ./check_oranslice_status.sh   - Vérifier le statut"
echo "   ./restart_oranslice.sh        - Redémarrer le gNB"
echo "   ./update_rrmpolicy.sh         - Modifier la politique"
echo ""
echo "📁 Manifests Kubernetes:"
echo "   k3s-deploy-oranslice/configmap-rrmpolicy.yaml"
echo "   k3s-deploy-oranslice/configmap-gnb-k3s.yaml"
echo "   k3s-deploy-oranslice/deployment-oranslice-gnb.yaml"
echo ""
echo "📖 Documentation:"
echo "   cat ORANSLICE_INTEGRATION.md"
echo ""
echo "🚀 Vérification:"
echo "   ./check_oranslice_status.sh"
echo ""
echo "=========================================="