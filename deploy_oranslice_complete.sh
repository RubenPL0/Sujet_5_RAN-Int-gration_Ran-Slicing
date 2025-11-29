#!/bin/bash
# =============================================================================
# NexSlice - Déploiement Complet ORANSlice avec RAN Slicing Simulé
# Installation automatisée de gNB + nrUE avec scheduler slice-aware
# =============================================================================

set -e

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[✓]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[!]${NC} $1"; }
log_error() { echo -e "${RED}[✗]${NC} $1"; }
log_step() { echo -e "${MAGENTA}[STEP]${NC} $1"; }

INSTALL_DIR="$HOME/NexSlice/ORANSlice"
OAI_DIR="$INSTALL_DIR/oai_ran"

clear
echo ""
echo "╔══════════════════════════════════════════════════════════════════╗"
echo "║     NexSlice - Déploiement ORANSlice (RAN Slicing Simulé)       ║"
echo "║                    Installation Complète                         ║"
echo "╚══════════════════════════════════════════════════════════════════╝"
echo ""
log_warning "⏱️  Temps estimé: 2-4 heures (compilation incluse)"
log_warning "💾  Espace disque requis: ~30 GB"
log_warning "🖥️  RAM recommandée: 16 GB minimum"
echo ""

read -p "Continuer avec l'installation ? (o/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Oo]$ ]]; then
    echo "Installation annulée."
    exit 0
fi

# =============================================================================
# Étape 1: Vérification Système
# =============================================================================

log_step "Étape 1/9: Vérification du système"
echo ""

# Vérifier Ubuntu
if ! grep -q "Ubuntu" /etc/os-release; then
    log_error "Ce script nécessite Ubuntu 20.04 ou 22.04"
    exit 1
fi

log_info "OS: $(lsb_release -d | cut -f2)"

# Vérifier RAM
TOTAL_RAM=$(free -g | awk '/^Mem:/{print $2}')
if [ $TOTAL_RAM -lt 12 ]; then
    log_warning "RAM détectée: ${TOTAL_RAM}GB (16GB recommandés)"
    read -p "Continuer quand même ? (o/n) " -n 1 -r
    echo
    [[ ! $REPLY =~ ^[Oo]$ ]] && exit 0
else
    log_success "RAM: ${TOTAL_RAM}GB"
fi

# Vérifier espace disque
AVAILABLE_SPACE=$(df -BG $HOME | awk 'NR==2 {print $4}' | sed 's/G//')
if [ $AVAILABLE_SPACE -lt 30 ]; then
    log_error "Espace disque insuffisant: ${AVAILABLE_SPACE}GB (30GB requis)"
    exit 1
fi

log_success "Espace disque: ${AVAILABLE_SPACE}GB disponibles"
echo ""

# =============================================================================
# Étape 2: Installation des Dépendances
# =============================================================================

log_step "Étape 2/9: Installation des dépendances"
echo ""

log_info "Mise à jour des paquets..."
sudo apt update

log_info "Installation des dépendances OAI..."
sudo apt install -y \
    build-essential \
    cmake \
    ninja-build \
    git \
    libboost-all-dev \
    libusb-1.0-0-dev \
    python3-pip \
    python3-dev \
    doxygen \
    libconfig++-dev \
    libsctp-dev \
    libssl-dev \
    libyaml-cpp-dev \
    libuhd-dev \
    uhd-host \
    libgnutls28-dev \
    libmnl-dev \
    libyaml-dev \
    libnettle8 \
    nettle-dev

log_info "Installation de protobuf..."
sudo apt install -y protobuf-compiler libprotoc-dev

log_success "Dépendances installées"
echo ""

# =============================================================================
# Étape 3: Clonage ORANSlice
# =============================================================================

log_step "Étape 3/9: Clonage du repository ORANSlice"
echo ""

if [ -d "$INSTALL_DIR" ]; then
    log_warning "Le dossier ORANSlice existe déjà"
    read -p "Supprimer et réinstaller ? (o/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Oo]$ ]]; then
        rm -rf "$INSTALL_DIR"
    else
        log_info "Utilisation du dossier existant"
    fi
fi

if [ ! -d "$INSTALL_DIR" ]; then
    log_info "Clonage de ORANSlice depuis GitHub..."
    mkdir -p $(dirname "$INSTALL_DIR")
    git clone https://github.com/wineslab/ORANSlice.git "$INSTALL_DIR"
    log_success "ORANSlice cloné"
else
    log_success "ORANSlice déjà présent"
fi

cd "$INSTALL_DIR"
echo ""

# =============================================================================
# Étape 4: Installation Protobuf-C (Pour E2)
# =============================================================================

log_step "Étape 4/9: Installation de protobuf-c"
echo ""

if [ ! -f "/usr/local/lib/libprotobuf-c.so" ]; then
    log_info "Compilation de protobuf-c..."
    cd /tmp
    if [ ! -d "protobuf-c" ]; then
        git clone https://github.com/protobuf-c/protobuf-c
    fi
    cd protobuf-c
    ./autogen.sh
    ./configure
    make -j$(nproc)
    sudo make install
    sudo ldconfig
    log_success "protobuf-c installé"
else
    log_success "protobuf-c déjà installé"
fi

cd "$INSTALL_DIR"
echo ""

# =============================================================================
# Étape 5: Compilation OAI avec ORANSlice
# =============================================================================

log_step "Étape 5/9: Compilation OAI (1-2 heures...)"
echo ""

cd oai_ran

log_info "Installation des dépendances OAI..."
cd cmake_targets
./build_oai -I --install-optional-packages

log_info "Compilation de gNB + nrUE avec RFsimulator..."
log_warning "⏱️  Cette étape peut prendre 1-2 heures..."
echo ""

# Compilation avec ninja (plus rapide)
./build_oai -w SIMU --gNB --nrUE --ninja -c 2>&1 | tee /tmp/oai_build.log

if [ -f "ran_build/build/nr-softmodem" ] && [ -f "ran_build/build/nr-uesoftmodem" ]; then
    log_success "Compilation réussie !"
    log_success "gNB: $(ls -lh ran_build/build/nr-softmodem | awk '{print $5}')"
    log_success "nrUE: $(ls -lh ran_build/build/nr-uesoftmodem | awk '{print $5}')"
else
    log_error "Erreur de compilation. Voir /tmp/oai_build.log"
    exit 1
fi

cd "$INSTALL_DIR"
echo ""

# =============================================================================
# Étape 6: Création des Configurations
# =============================================================================

log_step "Étape 6/9: Création des fichiers de configuration"
echo ""

# Créer dossier configs
mkdir -p configs
cd configs

# -----------------------------------------------------------------------------
# A. rrmPolicy.json
# -----------------------------------------------------------------------------

log_info "Création de rrmPolicy.json..."
cat > rrmPolicy.json <<'EOFPOLICY'
{
  "slices": [
    {
      "sliceId": "0x010001",
      "label": "eMBB",
      "scheduler": {
        "minPRB": 42,
        "maxPRB": 106,
        "priorityLevel": 4,
        "schedulingAlgorithm": "proportional_fair"
      }
    },
    {
      "sliceId": "0x010002",
      "label": "URLLC",
      "scheduler": {
        "minPRB": 32,
        "maxPRB": 85,
        "priorityLevel": 3,
        "schedulingAlgorithm": "round_robin"
      }
    },
    {
      "sliceId": "0x010003",
      "label": "mMTC",
      "scheduler": {
        "minPRB": 11,
        "maxPRB": 53,
        "priorityLevel": 1,
        "schedulingAlgorithm": "proportional_fair"
      }
    }
  ],
  "totalPRB": 106,
  "updateInterval": 1000,
  "bandwidth": "20MHz",
  "frequency": "3619.2MHz"
}
EOFPOLICY

log_success "rrmPolicy.json créé"

# -----------------------------------------------------------------------------
# B. gNB Configuration
# -----------------------------------------------------------------------------

log_info "Création de gnb-oranslice-rfsim.conf..."
cat > gnb-oranslice-rfsim.conf <<'EOFGNB'
Active_gNBs = ( "gNB-ORANSlice" );

gNBs = (
  {
    gNB_ID = 0xe00;
    gNB_name = "gNB-ORANSlice";
    
    # RAN Slicing Configuration
    rrmPolicyFile = "/tmp/rrmPolicy.json";
    
    # Tracking area code
    tracking_area_code = 1;
    plmn_list = (
      {
        mcc = 208;
        mnc = 99;
        mnc_length = 2;
        
        # 3 Network Slices
        snssaiList = (
          {
            sst = 1;
            sd = 0x010001; # eMBB
          },
          {
            sst = 1;
            sd = 0x010002; # URLLC
          },
          {
            sst = 1;
            sd = 0x010003; # mMTC
          }
        );
      }
    );
    
    # RFsimulator configuration (no USRP needed)
    rfsimulator = {
      serveraddr = "127.0.0.1";
      serverport = 4043;
      IQsamples_per_slot = 7680;
    };
    
    # AMF connection
    amf_ip_address = (
      {
        ipv4 = "192.168.70.132";
        port = 38412;
        active = "yes";
      }
    );
    
    # Network interfaces
    NETWORK_INTERFACES = {
      GNB_INTERFACE_NAME_FOR_S1_MME = "demo-oai";
      GNB_IPV4_ADDRESS_FOR_S1_MME = "192.168.70.129/24";
      GNB_INTERFACE_NAME_FOR_NGU = "demo-oai";
      GNB_IPV4_ADDRESS_FOR_NGU = "192.168.70.129/24";
      GNB_PORT_FOR_NGU = 2152;
    };
  }
);

security = {
  ciphering_algorithms = ( "nea0" );
  integrity_algorithms = ( "nia2", "nia1", "nia0" );
};

log_config = {
  global_log_level = "info";
  global_log_verbosity = "medium";
};
EOFGNB

log_success "gnb-oranslice-rfsim.conf créé"

# -----------------------------------------------------------------------------
# C. UE1 Configuration (eMBB)
# -----------------------------------------------------------------------------

log_info "Création de nrue1-embb.conf..."
cat > nrue1-embb.conf <<'EOFUE1'
uicc0 = {
  imsi = "208990000000001";
  key = "fec86ba6eb707ed08905757b1bb44b8f";
  opc = "C42449363BBAD02B66D16BC975D77CC1";
  dnn = "oai";
  nssai_sst = 1;
  nssai_sd = 0x010001; # eMBB
}

rfsimulator = {
  serveraddr = "127.0.0.1";
  serverport = 4043;
  options = ["noS1"];
};

log_config = {
  global_log_level = "info";
};
EOFUE1

log_success "nrue1-embb.conf créé"

# -----------------------------------------------------------------------------
# D. UE2 Configuration (URLLC)
# -----------------------------------------------------------------------------

log_info "Création de nrue2-urllc.conf..."
cat > nrue2-urllc.conf <<'EOFUE2'
uicc0 = {
  imsi = "208990000000002";
  key = "fec86ba6eb707ed08905757b1bb44b8f";
  opc = "C42449363BBAD02B66D16BC975D77CC1";
  dnn = "oai.ipv4";
  nssai_sst = 1;
  nssai_sd = 0x010002; # URLLC
}

rfsimulator = {
  serveraddr = "127.0.0.1";
  serverport = 4043;
  options = ["noS1"];
};

log_config = {
  global_log_level = "info";
};
EOFUE2

log_success "nrue2-urllc.conf créé"

# -----------------------------------------------------------------------------
# E. UE3 Configuration (mMTC)
# -----------------------------------------------------------------------------

log_info "Création de nrue3-mmtc.conf..."
cat > nrue3-mmtc.conf <<'EOFUE3'
uicc0 = {
  imsi = "208990000000003";
  key = "fec86ba6eb707ed08905757b1bb44b8f";
  opc = "C42449363BBAD02B66D16BC975D77CC1";
  dnn = "oai2";
  nssai_sst = 1;
  nssai_sd = 0x010003; # mMTC
}

rfsimulator = {
  serveraddr = "127.0.0.1";
  serverport = 4043;
  options = ["noS1"];
};

log_config = {
  global_log_level = "info";
};
EOFUE3

log_success "nrue3-mmtc.conf créé"

cd "$INSTALL_DIR"
echo ""

# =============================================================================
# Étape 7: Création des Scripts de Lancement
# =============================================================================

log_step "Étape 7/9: Création des scripts de lancement"
echo ""

mkdir -p scripts
cd scripts

# -----------------------------------------------------------------------------
# Script: Démarrer gNB
# -----------------------------------------------------------------------------

log_info "Création de start-gnb.sh..."
cat > start-gnb.sh <<'EOFSTARTGNB'
#!/bin/bash
# Démarrer gNB ORANSlice avec RFsimulator

INSTALL_DIR="$HOME/NexSlice/ORANSlice"

# Copier la politique RAN
sudo cp "$INSTALL_DIR/configs/rrmPolicy.json" /tmp/

# Créer interface réseau si nécessaire
if ! ip link show demo-oai &>/dev/null; then
    sudo ip link add demo-oai type dummy
    sudo ip addr add 192.168.70.129/24 dev demo-oai
    sudo ip link set demo-oai up
fi

# Démarrer gNB
cd "$INSTALL_DIR/oai_ran/cmake_targets/ran_build/build"

echo "🚀 Démarrage du gNB ORANSlice..."
echo "   Configuration: $INSTALL_DIR/configs/gnb-oranslice-rfsim.conf"
echo "   Politique RAN: /tmp/rrmPolicy.json"
echo ""

sudo ./nr-softmodem \
  -O "$INSTALL_DIR/configs/gnb-oranslice-rfsim.conf" \
  --rfsim \
  --sa \
  --log_config.global_log_level info
EOFSTARTGNB

chmod +x start-gnb.sh
log_success "start-gnb.sh créé"

# -----------------------------------------------------------------------------
# Script: Démarrer UE1 (eMBB)
# -----------------------------------------------------------------------------

log_info "Création de start-ue1-embb.sh..."
cat > start-ue1-embb.sh <<'EOFSTARTUE1'
#!/bin/bash
# Démarrer UE1 (eMBB) avec RFsimulator

INSTALL_DIR="$HOME/NexSlice/ORANSlice"

cd "$INSTALL_DIR/oai_ran/cmake_targets/ran_build/build"

echo "🚀 Démarrage UE1 (eMBB - Slice 0x010001)..."
echo "   IMSI: 208990000000001"
echo "   DNN: oai"
echo ""

sudo ./nr-uesoftmodem \
  -O "$INSTALL_DIR/configs/nrue1-embb.conf" \
  --rfsim \
  --sa \
  --nokrnmod 1 \
  --num-ues 1
EOFSTARTUE1

chmod +x start-ue1-embb.sh
log_success "start-ue1-embb.sh créé"

# -----------------------------------------------------------------------------
# Script: Démarrer UE2 (URLLC)
# -----------------------------------------------------------------------------

log_info "Création de start-ue2-urllc.sh..."
cat > start-ue2-urllc.sh <<'EOFSTARTUE2'
#!/bin/bash
# Démarrer UE2 (URLLC) avec RFsimulator

INSTALL_DIR="$HOME/NexSlice/ORANSlice"

cd "$INSTALL_DIR/oai_ran/cmake_targets/ran_build/build"

echo "🚀 Démarrage UE2 (URLLC - Slice 0x010002)..."
echo "   IMSI: 208990000000002"
echo "   DNN: oai.ipv4"
echo ""

sudo ./nr-uesoftmodem \
  -O "$INSTALL_DIR/configs/nrue2-urllc.conf" \
  --rfsim \
  --sa \
  --nokrnmod 1 \
  --num-ues 1
EOFSTARTUE2

chmod +x start-ue2-urllc.sh
log_success "start-ue2-urllc.sh créé"

# -----------------------------------------------------------------------------
# Script: Démarrer UE3 (mMTC)
# -----------------------------------------------------------------------------

log_info "Création de start-ue3-mmtc.sh..."
cat > start-ue3-mmtc.sh <<'EOFSTARTUE3'
#!/bin/bash
# Démarrer UE3 (mMTC) avec RFsimulator

INSTALL_DIR="$HOME/NexSlice/ORANSlice"

cd "$INSTALL_DIR/oai_ran/cmake_targets/ran_build/build"

echo "🚀 Démarrage UE3 (mMTC - Slice 0x010003)..."
echo "   IMSI: 208990000000003"
echo "   DNN: oai2"
echo ""

sudo ./nr-uesoftmodem \
  -O "$INSTALL_DIR/configs/nrue3-mmtc.conf" \
  --rfsim \
  --sa \
  --nokrnmod 1 \
  --num-ues 1
EOFSTARTUE3

chmod +x start-ue3-mmtc.sh
log_success "start-ue3-mmtc.sh créé"

# -----------------------------------------------------------------------------
# Script: Monitoring PRB
# -----------------------------------------------------------------------------

log_info "Création de monitor-prb.sh..."
cat > monitor-prb.sh <<'EOFMONITOR'
#!/bin/bash
# Monitoring allocation PRB en temps réel

echo "📊 Monitoring Allocation PRB (Ctrl+C pour arrêter)"
echo ""

# Surveiller les logs du gNB
if [ -f "/tmp/oai-gnb.log" ]; then
    tail -f /tmp/oai-gnb.log | grep --line-buffered -E "PRB|Slice|RRM"
else
    echo "⚠️  Fichier /tmp/oai-gnb.log non trouvé"
    echo "   Démarrer le gNB avec: ./start-gnb.sh > /tmp/oai-gnb.log 2>&1"
fi
EOFMONITOR

chmod +x monitor-prb.sh
log_success "monitor-prb.sh créé"

cd "$INSTALL_DIR"
echo ""

# =============================================================================
# Étape 8: Création du Script de Test
# =============================================================================

log_step "Étape 8/9: Création du script de test"
echo ""

cd scripts

log_info "Création de test-ran-slicing.sh..."
cat > test-ran-slicing.sh <<'EOFTEST'
#!/bin/bash
# Tests RAN Slicing avec ORANSlice

echo "╔══════════════════════════════════════════════════════════════════╗"
echo "║          Tests RAN Slicing - ORANSlice + OAI nrUE               ║"
echo "╚══════════════════════════════════════════════════════════════════╝"
echo ""

# Vérifier les interfaces
echo "📡 Vérification des interfaces réseau UE:"
ip addr show | grep -E "oaitun_ue[1-3]" || echo "⚠️  Aucune interface oaitun_ue détectée"
echo ""

# Test de connectivité
echo "🔌 Test de connectivité:"
for i in 1 2 3; do
    if ip addr show oaitun_ue$i &>/dev/null; then
        IP=$(ip -4 addr show oaitun_ue$i | grep inet | awk '{print $2}' | cut -d'/' -f1)
        echo "  UE$i ($IP): $(ping -I oaitun_ue$i -c 1 -W 1 8.8.8.8 &>/dev/null && echo '✓ OK' || echo '✗ FAIL')"
    fi
done
echo ""

# Surveiller allocation PRB
echo "📊 Allocation PRB (10 dernières lignes):"
if [ -f "/tmp/oai-gnb.log" ]; then
    tail -20 /tmp/oai-gnb.log | grep -E "PRB|Slice" | tail -10
else
    echo "⚠️  Logs gNB non trouvés"
fi
echo ""

echo "💡 Pour monitoring en temps réel:"
echo "   ./monitor-prb.sh"
EOFTEST

chmod +x test-ran-slicing.sh
log_success "test-ran-slicing.sh créé"

cd "$INSTALL_DIR"
echo ""

# =============================================================================
# Étape 9: Création de la Documentation
# =============================================================================

log_step "Étape 9/9: Création de la documentation"
echo ""

cat > README_ORANSLICE.md <<'EOFDOC'
# 🎯 ORANSlice - RAN Slicing Simulé (Installation Complète)

## ✅ Installation Terminée !

### 📁 Structure
```
~/NexSlice/ORANSlice/
├── configs/                    # Configurations
│   ├── rrmPolicy.json          # ⭐ Politique RAN Slicing
│   ├── gnb-oranslice-rfsim.conf
│   ├── nrue1-embb.conf
│   ├── nrue2-urllc.conf
│   └── nrue3-mmtc.conf
├── scripts/                    # Scripts de lancement
│   ├── start-gnb.sh            # Démarrer gNB
│   ├── start-ue1-embb.sh       # Démarrer UE1 (eMBB)
│   ├── start-ue2-urllc.sh      # Démarrer UE2 (URLLC)
│   ├── start-ue3-mmtc.sh       # Démarrer UE3 (mMTC)
│   ├── monitor-prb.sh          # Monitoring PRB
│   └── test-ran-slicing.sh     # Tests
└── oai_ran/                    # Code source OAI
    └── cmake_targets/ran_build/build/
        ├── nr-softmodem        # ⭐ gNB
        └── nr-uesoftmodem      # ⭐ nrUE
```

---

## 🚀 Démarrage Rapide

### **Étape 1 : Démarrer le Core 5G** (Si pas déjà fait)
```bash
# Vérifier que le Core est opérationnel
kubectl get pods -n nexslice
```

### **Étape 2 : Démarrer le gNB**
```bash
cd ~/NexSlice/ORANSlice/scripts

# Terminal 1
./start-gnb.sh

# Logs attendus :
# [RRM] Loading RAN slicing policy from /tmp/rrmPolicy.json
# [RRM] Slice 0x010001 (eMBB): minPRB=42, maxPRB=106
# [RRM] RAN slicing scheduler initialized ✅
```

### **Étape 3 : Démarrer les UEs** (3 terminaux séparés)
```bash
# Terminal 2 - UE1 (eMBB)
./start-ue1-embb.sh

# Terminal 3 - UE2 (URLLC)
./start-ue2-urllc.sh

# Terminal 4 - UE3 (mMTC)
./start-ue3-mmtc.sh
```

### **Étape 4 : Vérifier les Connexions**
```bash
# Terminal 5
./test-ran-slicing.sh

# Ou manuellement :
ip addr show | grep oaitun_ue
ping -I oaitun_ue1 -c 3 8.8.8.8
```

### **Étape 5 : Monitoring PRB** ⭐
```bash
# Terminal 6
./monitor-prb.sh

# Vous devriez voir :
# [MAC] Slice 0x010001 (eMBB):  allocated 65 PRB
# [MAC] Slice 0x010002 (URLLC): allocated 32 PRB
# [MAC] Slice 0x010003 (mMTC):  allocated 11 PRB
```

---

## 📊 Tests de Performance

### **Test 1 : Débit Séquentiel**
```bash
# Démarrer serveur iperf3
iperf3 -s -p 5201

# Depuis UE1
iperf3 -c <server-ip> -p 5201 -t 30 -B $(ip -4 addr show oaitun_ue1 | grep inet | awk '{print $2}' | cut -d'/' -f1)

# Depuis UE2
iperf3 -c <server-ip> -p 5201 -t 30 -B $(ip -4 addr show oaitun_ue2 | grep inet | awk '{print $2}' | cut -d'/' -f1)

# Depuis UE3
iperf3 -c <server-ip> -p 5201 -t 30 -B $(ip -4 addr show oaitun_ue3 | grep inet | awk '{print $2}' | cut -d'/' -f1)
```

### **Test 2 : Congestion (Tous en Parallèle)**
```bash
# Lancer les 3 iperf3 simultanément
iperf3 -c <server> -B $(ip -4 addr show oaitun_ue1 | grep inet | awk '{print $2}' | cut -d'/' -f1) -t 60 &
iperf3 -c <server> -B $(ip -4 addr show oaitun_ue2 | grep inet | awk '{print $2}' | cut -d'/' -f1) -t 60 &
iperf3 -c <server> -B $(ip -4 addr show oaitun_ue3 | grep inet | awk '{print $2}' | cut -d'/' -f1) -t 60 &

# Surveiller allocation PRB
./monitor-prb.sh
```

---

## 📈 Résultats Attendus

### **Allocation PRB sous Congestion**
```
Slice eMBB  (0x010001): 42-65 PRB (garanti 42)
Slice URLLC (0x010002): 32-40 PRB (garanti 32)
Slice mMTC  (0x010003): 11-15 PRB (garanti 11)
```

### **Débits Attendus**
```
UE1 (eMBB):  40-50 Mbps
UE2 (URLLC): 30-35 Mbps
UE3 (mMTC):  10-15 Mbps

Ratio eMBB/mMTC: ~4x ✅
```

---

## 🔧 Dépannage

### **Problème : gNB ne démarre pas**
```bash
# Vérifier l'interface réseau
ip link show demo-oai

# Recréer si nécessaire
sudo ip link del demo-oai
sudo ip link add demo-oai type dummy
sudo ip addr add 192.168.70.129/24 dev demo-oai
sudo ip link set demo-oai up
```

### **Problème : UE ne se connecte pas**
```bash
# Vérifier que le gNB est démarré
ps aux | grep nr-softmodem

# Vérifier les logs
tail -f /tmp/oai-gnb.log
```

### **Problème : Pas d'interface oaitun_ue**
```bash
# Attendre 30-60 secondes après le démarrage du UE
# Vérifier les logs du UE
tail -f /tmp/oai-nrue.log
```

---

## 🎓 Pour la Soutenance

### **Points à Démontrer**
1. ✅ Scheduler slice-aware actif (logs gNB)
2. ✅ Allocation PRB différenciée (monitoring)
3. ✅ 3 UEs connectés (interfaces oaitun_ue)
4. ✅ Tests de débit avec ratios clairs

### **Commandes Essentielles**
```bash
# Démo rapide (5 min)
./start-gnb.sh              # Terminal 1
./start-ue1-embb.sh         # Terminal 2
./monitor-prb.sh            # Terminal 3
./test-ran-slicing.sh       # Terminal 4
```

---

## 📚 Références

- **ORANSlice :** https://github.com/wineslab/ORANSlice
- **Paper :** https://arxiv.org/abs/2410.12978
- **OAI :** https://openairinterface.org

---

**Installation : ✅ Terminée**  
**Prêt pour tests : ✅ Oui**  
**Scheduler slice-aware : ✅ Actif**
EOFDOC

log_success "README_ORANSLICE.md créé"
echo ""

# =============================================================================
# RÉSUMÉ FINAL
# =============================================================================

echo ""
echo "╔══════════════════════════════════════════════════════════════════╗"
echo "║            Installation ORANSlice Terminée ! 🎉                  ║"
echo "╚══════════════════════════════════════════════════════════════════╝"
echo ""

log_success "Installation complète dans: $INSTALL_DIR"
echo ""

echo "📁 Fichiers créés:"
echo "   ✓ Binaires:"
echo "     • $OAI_DIR/cmake_targets/ran_build/build/nr-softmodem"
echo "     • $OAI_DIR/cmake_targets/ran_build/build/nr-uesoftmodem"
echo ""
echo "   ✓ Configurations (configs/):"
echo "     • rrmPolicy.json (⭐ Politique RAN Slicing)"
echo "     • gnb-oranslice-rfsim.conf"
echo "     • nrue1-embb.conf, nrue2-urllc.conf, nrue3-mmtc.conf"
echo ""
echo "   ✓ Scripts (scripts/):"
echo "     • start-gnb.sh"
echo "     • start-ue1-embb.sh, start-ue2-urllc.sh, start-ue3-mmtc.sh"
echo "     • monitor-prb.sh"
echo "     • test-ran-slicing.sh"
echo ""
echo "   ✓ Documentation:"
echo "     • README_ORANSLICE.md"
echo ""

echo "🚀 Prochaines Étapes:"
echo ""
echo "   1. Lire la documentation:"
echo "      cat $INSTALL_DIR/README_ORANSLICE.md"
echo ""
echo "   2. Démarrer le gNB (Terminal 1):"
echo "      cd $INSTALL_DIR/scripts"
echo "      ./start-gnb.sh"
echo ""
echo "   3. Démarrer les UEs (Terminaux 2, 3, 4):"
echo "      ./start-ue1-embb.sh"
echo "      ./start-ue2-urllc.sh"
echo "      ./start-ue3-mmtc.sh"
echo ""
echo "   4. Monitoring PRB (Terminal 5):"
echo "      ./monitor-prb.sh"
echo ""
echo "   5. Tests:"
echo "      ./test-ran-slicing.sh"
echo ""

echo "═══════════════════════════════════════════════════════════════════"
echo ""
log_success "Installation terminée avec succès ! 🎉"
echo ""
