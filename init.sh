#!/bin/bash

DB_HOST=${DB_HOST:-db}
DB_NAME=${DB_NAME:-drupal}
DB_USER=${DB_USER:-drupal}
DB_PASSWORD=${DB_PASSWORD:-drupal}
HASH_SALT=$(openssl rand -base64 32)  # Générer un hash_salt unique

# Attendre que la base de données soit prête
echo "Attente de la base de données..."
timeout 60s bash -c "until mysqladmin ping -h \"$DB_HOST\" -u \"$DB_USER\" -p\"$DB_PASSWORD\" --silent; do echo \"Base de données non prête, attente 2 secondes...\"; sleep 2; done"
if [ $? -eq 0 ]; then
    echo "Base de données prête !"
else
    echo "Erreur : Impossible de se connecter à la base de données après 60 secondes."
    exit 1
fi

# Préparer les répertoires et permissions
echo "Configuration des permissions..."
mkdir -p web/sites/default/files config
chown -R www-data:www-data web/sites/default web/sites/default/files config
chmod -R 775 web/sites/default web/sites/default/files config

# Vérifier si settings.php existe, sinon le créer
if [ ! -f "web/sites/default/settings.php" ]; then
    echo "Préparation de settings.php..."
    cp web/sites/default/default.settings.php web/sites/default/settings.php
    chown www-data:www-data web/sites/default/settings.php
    chmod 664 web/sites/default/settings.php
fi

# Ajouter les variables d'environnement et hash_salt à settings.php (si pas déjà présent)
if ! grep -q "getenv('DB_HOST')" web/sites/default/settings.php; then
    echo "Ajout des variables d'environnement à settings.php..."
    cat <<EOL >> web/sites/default/settings.php

// Configuration dynamique de la base de données via variables d'environnement
\$databases['default']['default'] = [
  'database' => getenv('DB_NAME') ?: '$DB_NAME',
  'username' => getenv('DB_USER') ?: '$DB_USER',
  'password' => getenv('DB_PASSWORD') ?: '$DB_PASSWORD',
  'host' => getenv('DB_HOST') ?: '$DB_HOST',
  'port' => '3306',
  'driver' => 'mysql',
  'prefix' => '',
  'collation' => 'utf8mb4_general_ci',
];

// Hash salt pour la sécurité
\$settings['hash_salt'] = '$HASH_SALT';
EOL
fi

# Vérifier l'état de Drupal avec drush status
echo "Vérification de l'état de Drupal..."
DRUSH_STATUS=$(vendor/bin/drush status --fields=bootstrap --format=string 2>/dev/null)
if [ "$DRUSH_STATUS" != "Successful" ]; then
    echo "Drupal n'est pas installé ou mal configuré. Installation en cours..."
    vendor/bin/drush site:install standard \
        --db-url="mysql://${DB_USER}:${DB_PASSWORD}@${DB_HOST}/${DB_NAME}" \
        --site-name="Pantheon-like Drupal" \
        --account-name=admin \
        --account-pass=admin \
        --no-interaction \
        -y
    if [ $? -eq 0 ]; then
        echo "Installation terminée avec succès !"
    else
        echo "Erreur : L'installation de Drupal a échoué."
        exit 1
    fi
else
    echo "Drupal est déjà installé et opérationnel."
fi

# Vider le cache avant l'export pour s'assurer que Drush est à jour
echo "Vidage du cache Drupal..."
vendor/bin/drush cr

# Exporter la configuration (non bloquant si ça échoue)
echo "Exportation de la configuration..."
vendor/bin/drush config-export -y
if [ $? -eq 0 ]; then
    echo "Configuration exportée avec succès !"
else
    echo "Avertissement : Échec de l'exportation de la configuration. Vous pouvez le faire manuellement avec 'drush config-export'."
fi

echo "Démarrage d'Apache..."
exec apache2-foreground
