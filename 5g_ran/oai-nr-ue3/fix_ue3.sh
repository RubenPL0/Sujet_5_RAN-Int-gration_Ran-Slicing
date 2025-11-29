#!/bin/bash
# =============================================================================
# Fix complet pour oai-nr-ue3
# =============================================================================

cd ~/NexSlice/5g_ran/oai-nr-ue3

echo "🔧 Correction complète de oai-nr-ue3..."
echo ""

# =============================================================================
# 1. Supprimer le déploiement problématique
# =============================================================================

echo "[1/5] Suppression du déploiement actuel..."
helm uninstall nrue3 -n nexslice 2>/dev/null || echo "  (déjà supprimé)"
sleep 5

# =============================================================================
# 2. Créer le template configmap.yaml s'il manque
# =============================================================================

echo "[2/5] Création du template configmap.yaml..."

cat > templates/configmap.yaml << 'EOF'
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ include "oai-nr-ue.fullname" . }}-configmap
  labels:
    {{- include "oai-nr-ue.labels" . | nindent 4 }}
data:
  ue.conf: |
    uicc0 = {
      imsi = "{{ .Values.config.fullImsi }}";
      key = "{{ .Values.config.fullKey }}";
      opc= "{{ .Values.config.opc }}";
      dnn= "{{ .Values.config.dnn }}";
      nssai_sst={{ .Values.config.nssaiSst }};
      {{- if .Values.config.nssaiSd }}
      nssai_sd={{ .Values.config.nssaiSd }};
      {{- end }}
    }
EOF

echo "  ✓ configmap.yaml créé"

# =============================================================================
# 3. Corriger deployment.yaml pour USE_ADDITIONAL_OPTIONS
# =============================================================================

echo "[3/5] Correction de deployment.yaml..."

# Vérifier si deployment.yaml existe
if [ -f templates/deployment.yaml ]; then
    # Remplacer nssai_sst 2 par nssai_sst {{ .Values.config.nssaiSst }}
    sed -i 's/--uicc0.nssai_sst 2/--uicc0.nssai_sst {{ .Values.config.nssaiSst }}/g' templates/deployment.yaml
    
    # Vérifier
    if grep -q "nssai_sst {{ .Values.config.nssaiSst }}" templates/deployment.yaml; then
        echo "  ✓ deployment.yaml corrigé"
    else
        echo "  ⚠ Vérifier manuellement deployment.yaml"
    fi
else
    echo "  ⚠ deployment.yaml non trouvé"
fi

# =============================================================================
# 4. Vérifier/Corriger values.yaml
# =============================================================================

echo "[4/5] Vérification de values.yaml..."

# Vérifier les valeurs clés
if grep -q 'nssaiSst: "3"' values.yaml && \
   grep -q 'nssaiSd: "0x000003"' values.yaml && \
   grep -q 'dnn: "slice3"' values.yaml && \
   grep -q 'fullImsi: "001010000000003"' values.yaml; then
    echo "  ✓ values.yaml OK"
else
    echo "  ⚠ Correction de values.yaml..."
    
    # Créer un values.yaml correct
    cat > values.yaml << 'EOFVAL'
kubernetesType: Vanilla

nfimage:
  registry: docker.io
  repository: oaisoftwarealliance/oai-nr-ue
  tag: develop
  pullPolicy: IfNotPresent

tcpdumpimage:
  registry: docker.io
  repository: corfr/tcpdump
  tag: latest
  pullPolicy: IfNotPresent

config:
  timeZone: "Europe/Paris"
  rfSimServer: "oai-du-svc"
  
  # UE3 Identity
  fullImsi: "001010000000003"
  fullKey: "fec86ba6eb707ed08905757b1bb44b8f"
  opc: "C42449363BBAD02B66D16BC975D77CC1"
  
  # Slice 3 (mMTC)
  dnn: "slice3"
  nssaiSst: "3"
  nssaiSd: "0x000003"
  
  useAdditionalOptions: "--sa --rfsim -r 106 --numerology 1 -C 3619200000 --ssb 516"

start:
  nrue: true
  tcpdump: false

includeTcpDumpContainer: false

securityContext:
  privileged: true

podSecurityContext:
  runAsUser: 0
  runAsGroup: 0

serviceAccount:
  create: true
  annotations: {}
  name: "oai-nr-ue3-sa"

rbac:
  create: true

resources:
  define: true
  limits:
    cpu: "2"
    memory: "4Gi"
  requests:
    cpu: "1"
    memory: "2Gi"

readinessProbe: true
livenessProbe: false

nodeSelector: {}
tolerations: []
affinity: {}

podLabels: {}
podAnnotations: {}

multus:
  create: false

persistence:
  enabled: false
EOFVAL

    echo "  ✓ values.yaml recréé"
fi

# =============================================================================
# 5. Vérifier la structure des templates
# =============================================================================

echo "[5/5] Vérification des templates..."

REQUIRED_TEMPLATES=("_helpers.tpl" "configmap.yaml" "deployment.yaml" "serviceaccount.yaml" "rbac.yaml")

for tpl in "${REQUIRED_TEMPLATES[@]}"; do
    if [ -f "templates/$tpl" ]; then
        echo "  ✓ templates/$tpl"
    else
        echo "  ✗ templates/$tpl MANQUANT"
        
        # Si c'est _helpers.tpl, on peut le copier depuis oai-nr-ue2
        if [ "$tpl" = "_helpers.tpl" ] && [ -f "../oai-nr-ue2/templates/_helpers.tpl" ]; then
            cp ../oai-nr-ue2/templates/_helpers.tpl templates/
            sed -i 's/oai-nr-ue2/oai-nr-ue3/g' templates/_helpers.tpl
            echo "    → copié et corrigé depuis oai-nr-ue2"
        fi
    fi
done

# =============================================================================
# 6. Réinstaller
# =============================================================================

echo ""
echo "╔════════════════════════════════════════════════════════════╗"
echo "║              Installation de oai-nr-ue3                    ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

cd ~/NexSlice

helm install nrue3 5g_ran/oai-nr-ue3/ -n nexslice

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ Installation réussie !"
    echo ""
    echo "Attendre 30 secondes puis vérifier:"
    echo "  sudo k3s kubectl get pods -n nexslice | grep ue3"
    echo "  sudo k3s kubectl logs -n nexslice -l app.kubernetes.io/name=oai-nr-ue3 -f"
    echo ""
else
    echo ""
    echo "❌ Erreur lors de l'installation"
    echo ""
    echo "Debug:"
    echo "  helm install nrue3 5g_ran/oai-nr-ue3/ -n nexslice --debug --dry-run"
    echo ""
fi