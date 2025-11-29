#!/bin/bash
# Script d'installation des prérequis pour l'intégration ORANSlice → NexSlice
# Compatible Ubuntu 22.04 / 24.04

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_banner() {
    echo ""
    echo "╔═══════════════════════════════════════════════════════╗"
    echo "║   Installation des Prérequis                         ║"
    echo "║   ORANSlice → NexSlice                               ║"
    echo "╚═══════════════════════════════════════════════════════╝"
    echo ""
}

check_root() {
    if [ "$EUID" -ne 0 ]; then 
        log_error "Ce script doit être exécuté en tant que root ou avec sudo"
        exit 1
    fi
}

detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$NAME
        VER=$VERSION_ID
        log_info "Système détecté: $OS $VER"
    else
        log_error "Impossible de détecter le système d'exploitation"
        exit 1
    fi
}

update_system() {
    log_info "Mise à jour du système..."
    apt-get update
    apt-get upgrade -y
    log_success "Système mis à jour"
}

install_basic_tools() {
    log_info "Installation des outils de base..."
    
    apt-get install -y \
        curl \
        wget \
        git \
        vim \
        nano \
        apt-transport-https \
        ca-certificates \
        gnupg \
        lsb-release \
        software-properties-common \
        build-essential \
        jq \
        net-tools \
        iputils-ping
    
    log_success "Outils de base installés"
}

install_docker() {
    log_info "Installation de Docker..."
    
    # Vérifier si Docker est déjà installé
    if command -v docker &> /dev/null; then
        DOCKER_VERSION=$(docker --version)
        log_warning "Docker est déjà installé: $DOCKER_VERSION"
        read -p "Voulez-vous réinstaller Docker? (y/n): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "Installation de Docker ignorée"
            return
        fi
    fi
    
    # Supprimer les anciennes versions
    log_info "Suppression des anciennes versions de Docker..."
    apt-get remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true
    
    # Ajouter le dépôt Docker
    log_info "Ajout du dépôt Docker officiel..."
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    chmod a+r /etc/apt/keyrings/docker.gpg
    
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
      $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    # Installer Docker
    log_info "Installation de Docker Engine..."
    apt-get update
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    
    # Démarrer et activer Docker
    systemctl start docker
    systemctl enable docker
    
    # Vérifier l'installation
    if docker run hello-world &> /dev/null; then
        log_success "Docker installé et fonctionnel"
        docker --version
    else
        log_error "Problème lors de l'installation de Docker"
        exit 1
    fi
}

configure_docker_user() {
    log_info "Configuration des permissions Docker..."
    
    # Demander le nom d'utilisateur
    if [ -n "$SUDO_USER" ]; then
        USERNAME=$SUDO_USER
    else
        read -p "Entrez le nom d'utilisateur à ajouter au groupe docker: " USERNAME
    fi
    
    if id "$USERNAME" &>/dev/null; then
        usermod -aG docker $USERNAME
        log_success "Utilisateur $USERNAME ajouté au groupe docker"
        log_warning "IMPORTANT: Déconnectez-vous et reconnectez-vous pour que les changements prennent effet"
        log_warning "Ou exécutez: newgrp docker"
    else
        log_warning "Utilisateur $USERNAME introuvable"
    fi
}

install_kubectl() {
    log_info "Installation de kubectl..."
    
    if command -v kubectl &> /dev/null; then
        KUBECTL_VERSION=$(kubectl version --client --short 2>/dev/null || kubectl version --client)
        log_warning "kubectl est déjà installé: $KUBECTL_VERSION"
        return
    fi
    
    # Télécharger kubectl
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
    
    # Vérifier le binaire
    curl -LO "https://dl.k8s.io/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl.sha256"
    echo "$(cat kubectl.sha256)  kubectl" | sha256sum --check
    
    # Installer kubectl
    install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
    
    # Nettoyer
    rm kubectl kubectl.sha256
    
    # Vérifier l'installation
    kubectl version --client
    log_success "kubectl installé"
}

install_helm() {
    log_info "Installation de Helm..."
    
    if command -v helm &> /dev/null; then
        HELM_VERSION=$(helm version --short)
        log_warning "Helm est déjà installé: $HELM_VERSION"
        return
    fi
    
    # Télécharger et installer Helm
    curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
    
    # Vérifier l'installation
    helm version
    log_success "Helm installé"
}

install_kubernetes_tools() {
    log_info "Installation des outils Kubernetes supplémentaires..."
    
    # k9s (CLI pour Kubernetes)
    if ! command -v k9s &> /dev/null; then
        log_info "Installation de k9s..."
        K9S_VERSION=$(curl -s https://api.github.com/repos/derailed/k9s/releases/latest | grep tag_name | cut -d '"' -f 4)
        wget https://github.com/derailed/k9s/releases/download/${K9S_VERSION}/k9s_Linux_amd64.tar.gz
        tar -xzf k9s_Linux_amd64.tar.gz
        mv k9s /usr/local/bin/
        rm k9s_Linux_amd64.tar.gz LICENSE README.md
        log_success "k9s installé"
    fi
}

install_network_tools() {
    log_info "Installation des outils réseau..."
    
    apt-get install -y \
        iperf3 \
        tcpdump \
        wireshark-common \
        iproute2 \
        bridge-utils \
        traceroute \
        nmap \
        netcat
    
    log_success "Outils réseau installés"
}

install_protobuf() {
    log_info "Installation de Protobuf (requis pour OAI)..."
    
    apt-get install -y \
        protobuf-compiler \
        libprotobuf-dev \
        libprotoc-dev
    
    # Protobuf-c (nécessaire pour ORANSlice)
    if ! command -v protoc-c &> /dev/null; then
        log_info "Installation de protobuf-c..."
        cd /tmp
        git clone https://github.com/protobuf-c/protobuf-c.git
        cd protobuf-c
        ./autogen.sh
        ./configure
        make
        make install
        ldconfig
        cd /tmp
        rm -rf protobuf-c
        log_success "protobuf-c installé"
    fi
}

verify_installation() {
    log_info "Vérification de l'installation..."
    echo ""
    
    local all_ok=true
    
    # Docker
    if command -v docker &> /dev/null; then
        echo "✅ Docker: $(docker --version)"
    else
        echo "❌ Docker: Non installé"
        all_ok=false
    fi
    
    # kubectl
    if command -v kubectl &> /dev/null; then
        echo "✅ kubectl: $(kubectl version --client --short 2>/dev/null || echo $(kubectl version --client | grep 'Client Version'))"
    else
        echo "❌ kubectl: Non installé"
        all_ok=false
    fi
    
    # Helm
    if command -v helm &> /dev/null; then
        echo "✅ Helm: $(helm version --short)"
    else
        echo "❌ Helm: Non installé"
        all_ok=false
    fi
    
    # Git
    if command -v git &> /dev/null; then
        echo "✅ Git: $(git --version)"
    else
        echo "❌ Git: Non installé"
        all_ok=false
    fi
    
    # jq
    if command -v jq &> /dev/null; then
        echo "✅ jq: $(jq --version)"
    else
        echo "❌ jq: Non installé"
        all_ok=false
    fi
    
    # Protobuf
    if command -v protoc &> /dev/null; then
        echo "✅ Protobuf: $(protoc --version)"
    else
        echo "❌ Protobuf: Non installé"
        all_ok=false
    fi
    
    echo ""
    
    if $all_ok; then
        log_success "Tous les prérequis sont installés !"
        return 0
    else
        log_warning "Certains outils ne sont pas installés"
        return 1
    fi
}

print_next_steps() {
    echo ""
    echo "╔═══════════════════════════════════════════════════════╗"
    echo "║           Installation terminée !                     ║"
    echo "╚═══════════════════════════════════════════════════════╝"
    echo ""
    log_success "Tous les prérequis ont été installés avec succès"
    echo ""
    echo "📋 Prochaines étapes:"
    echo ""
    echo "1. Déconnectez-vous et reconnectez-vous (pour Docker)"
    echo "   OU exécutez: newgrp docker"
    echo ""
    echo "2. Vérifiez que Docker fonctionne:"
    echo "   docker run hello-world"
    echo ""
    echo "3. Si vous avez Kubernetes:"
    echo "   kubectl cluster-info"
    echo ""
    echo "4. Lancez l'intégration ORANSlice:"
    echo "   cd /path/to/nexslice"
    echo "   ./integrate_oranslice_in_nexslice.sh"
    echo ""
    echo "💡 Astuces:"
    echo "   - Docker: docker ps (voir les conteneurs)"
    echo "   - Kubectl: kubectl get nodes (voir les nœuds)"
    echo "   - Helm: helm list (voir les déploiements)"
    echo "   - k9s: k9s (interface TUI pour K8s)"
    echo ""
}

# Menu interactif
show_menu() {
    echo ""
    echo "╔═══════════════════════════════════════════════════════╗"
    echo "║        Que voulez-vous installer ?                   ║"
    echo "╚═══════════════════════════════════════════════════════╝"
    echo ""
    echo "1) Installation complète (Recommandé)"
    echo "2) Docker uniquement"
    echo "3) Kubernetes tools (kubectl + Helm)"
    echo "4) Outils réseau"
    echo "5) Protobuf (pour OAI)"
    echo "6) Vérifier l'installation"
    echo "7) Quitter"
    echo ""
    read -p "Votre choix [1-7]: " choice
    
    case $choice in
        1)
            update_system
            install_basic_tools
            install_docker
            configure_docker_user
            install_kubectl
            install_helm
            install_kubernetes_tools
            install_network_tools
            install_protobuf
            verify_installation
            print_next_steps
            ;;
        2)
            install_docker
            configure_docker_user
            verify_installation
            ;;
        3)
            install_kubectl
            install_helm
            install_kubernetes_tools
            verify_installation
            ;;
        4)
            install_network_tools
            verify_installation
            ;;
        5)
            install_protobuf
            verify_installation
            ;;
        6)
            verify_installation
            ;;
        7)
            log_info "Au revoir !"
            exit 0
            ;;
        *)
            log_error "Choix invalide"
            show_menu
            ;;
    esac
}

# Main
main() {
    print_banner
    check_root
    detect_os
    
    # Si des arguments sont passés, installation automatique
    if [ $# -eq 0 ]; then
        show_menu
    else
        case "$1" in
            --full|--all)
                log_info "Installation complète automatique..."
                update_system
                install_basic_tools
                install_docker
                configure_docker_user
                install_kubectl
                install_helm
                install_kubernetes_tools
                install_network_tools
                install_protobuf
                verify_installation
                print_next_steps
                ;;
            --docker)
                install_docker
                configure_docker_user
                verify_installation
                ;;
            --k8s|--kubernetes)
                install_kubectl
                install_helm
                install_kubernetes_tools
                verify_installation
                ;;
            --verify|--check)
                verify_installation
                ;;
            --help|-h)
                echo "Usage: $0 [option]"
                echo ""
                echo "Options:"
                echo "  --full, --all      Installation complète"
                echo "  --docker           Installer Docker uniquement"
                echo "  --k8s, --kubernetes Installer kubectl et Helm"
                echo "  --verify, --check  Vérifier l'installation"
                echo "  --help, -h         Afficher cette aide"
                echo ""
                echo "Sans option: Mode interactif"
                ;;
            *)
                log_error "Option inconnue: $1"
                echo "Utilisez --help pour voir les options disponibles"
                exit 1
                ;;
        esac
    fi
}

# Exécution
main "$@"