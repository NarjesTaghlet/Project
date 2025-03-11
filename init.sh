#!/bin/bash
# init.sh

DB_HOST=${DB_HOST:-db}
DB_NAME=${DB_NAME:-drupal}
DB_USER=${DB_USER:-drupal}
DB_PASSWORD=${DB_PASSWORD:-drupal}

# Installer Drupal si nécessaire
if [ ! -f "docroot/sites/default/settings.php" ]; then
    echo "Installation de Drupal..."
    vendor/bin/drush site:install standard \
        --db-url="mysql://${DB_USER}:${DB_PASSWORD}@${DB_HOST}/${DB_NAME}" \
        --site-name="Pantheon-like Drupal" \
        --account-name=admin \
        --account-pass=admin \
        --no-interaction
fi

# Importer la config si elle existe
if [ -d "config" ] && [ "$(ls -A config)" ]; then
    vendor/bin/drush config:import -y
fi

# Exporter la config
vendor/bin/drush config:export -y

exec apache2-foreground
