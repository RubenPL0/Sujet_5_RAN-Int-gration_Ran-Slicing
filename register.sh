#!/bin/bash

# Configuration
NAMESPACE="nexslice"
KUBECTL="sudo k3s kubectl"
# CORRECTION : Le label doit correspondre à la partie fixe du nom du pod (5gc-mysql)
LABEL="app.kubernetes.io/name=5gc-mysql" 

echo "## Étape 5 : Enregistrement de l'UE dans MySQL pour $NAMESPACE"
echo "---"

# 1. Attendre et récupérer le nom du pod MySQL
echo "🔍 Recherche du pod MySQL avec le label '$LABEL' dans le namespace '$NAMESPACE'..."
MAX_ATTEMPTS=10
ATTEMPTS=0
MYSQL_POD=""

# La boucle de recherche est maintenue pour gérer le cas où le pod redémarrerait.
while [ -z "$MYSQL_POD" ] && [ $ATTEMPTS -lt $MAX_ATTEMPTS ]; do
    # 2>/dev/null supprime les messages d'erreur de jsonpath pendant l'attente
    MYSQL_POD=$($KUBECTL get pods -n $NAMESPACE -l $LABEL -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    if [ -z "$MYSQL_POD" ]; then
        ATTEMPTS=$((ATTEMPTS + 1))
        echo "   Tentative $ATTEMPTS/$MAX_ATTEMPTS : Pod non trouvé ou non prêt. Attente de 5 secondes..."
        sleep 5
    fi
done

if [ -z "$MYSQL_POD" ]; then
    echo "❌ ÉCHEC : Le pod MySQL n'a pas pu être trouvé après $MAX_ATTEMPTS tentatives."
    echo "   Le label '$LABEL' semble toujours incorrect. Veuillez vérifier les labels réels du pod."
    exit 1
fi

echo "✅ Pod MySQL trouvé : $MYSQL_POD"

# 2. Créer le script SQL temporaire (inchangé)
SQL_FILE="/tmp/add_ue_$(date +%s).sql"

cat > "$SQL_FILE" <<'EOSQL'
USE oai_db;

DELETE FROM AuthenticationSubscription WHERE ueid='208990000000001';
DELETE FROM SessionManagementSubscriptionData WHERE ueid='208990000000001';
DELETE FROM AccessAndMobilitySubscriptionData WHERE ueid='208990000000001';

INSERT INTO AuthenticationSubscription (ueid, authenticationMethod, encPermanentKey, protectionParameterId, sequenceNumber, authenticationManagementField, algorithmId, encOpcKey, encTopcKey, vectorGenerationInHss, n5gcAuthMethod, rgAuthenticationInd, supi)
VALUES ('208990000000001', '5G_AKA', 'fec86ba6eb707ed08905757b1bb44b8f', 'fec86ba6eb707ed08905757b1bb44b8f', '{"sqn": "000000000020", "sqnScheme": "NON_TIME_BASED", "lastIndexes": {"ausf": 0}}', '8000', 'milenage', 'C42449363BBAD02B66D16BC975D77CC1', NULL, NULL, NULL, NULL, '208990000000001');

INSERT INTO SessionManagementSubscriptionData (ueid, servingPlmnid, singleNssai, dnnConfigurations)
VALUES ('208990000000001', '20899', '{"sst": 1, "sd": "ffffff"}', '{"oai":{"pduSessionTypes":{ "defaultSessionType": "IPV4"},"sscModes": {"defaultSscMode": "SSC_MODE_1"},"5gQosProfile": {"5qi": 9,"arp":{"priorityLevel": 15,"preemptCap": "NOT_PREEMPT","preemptVuln":"NOT_PREEMPTABLE"},"priorityLevel":1},"sessionAmbr":{"uplink":"100Mbps", "downlink":"100Mbps"}}}');

INSERT INTO AccessAndMobilitySubscriptionData (ueid, servingPlmnid, subscribedUeAmbr, nssai)
VALUES ('208990000000001', '20899', '{"uplink":"100Mbps","downlink":"100Mbps"}', '{"defaultSingleNssais": [{"sst": 1, "sd": "ffffff"}]}');
EOSQL

echo "📝 Script SQL créé à l'emplacement $SQL_FILE."

# 3. Copier et exécuter le script
echo "➡️ Copie et exécution du script SQL sur le pod $MYSQL_POD..."

# Copier le script
$KUBECTL cp "$SQL_FILE" "$NAMESPACE/$MYSQL_POD":/tmp/add_ue.sql
if [ $? -ne 0 ]; then
    echo "❌ ÉCHEC de la commande 'kubectl cp'. Le script SQL n'a pas été copié."
    rm -f "$SQL_FILE"
    exit 1
fi
echo "   Fichier SQL copié avec succès."

# Exécuter le script
$KUBECTL exec -n $NAMESPACE "$MYSQL_POD" -- mysql -u root -plinux < "$SQL_FILE"

# Vérification du statut de la dernière commande
if [ $? -eq 0 ]; then
    echo "🎉 Succès : Les données de l'UE '208990000000001' ont été enregistrées dans MySQL."
else
    echo "⚠️ AVERTISSEMENT : La commande d'exécution SQL a retourné une erreur. Veuillez vérifier les logs du pod MySQL."
fi

# 4. Nettoyage
rm -f "$SQL_FILE"
echo "🗑️ Fichier SQL temporaire local supprimé."