FROM php:8.2-apache

# Dépendances
RUN apt-get update && apt-get install -y \
    git zip unzip libpng-dev libjpeg-dev libzip-dev \
    default-libmysqlclient-dev mariadb-client \
    && docker-php-ext-install pdo_mysql gd zip \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

RUN a2enmod rewrite
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

WORKDIR /var/www/html

# Copier le code
COPY --chown=www-data:www-data ["./composer.json", "./composer.lock", "./"]
COPY --chown=www-data:www-data ["./web", "./web/", "./"]
COPY --chown=www-data:www-data ["./config", "./config/", "./"]

RUN composer install --no-dev --optimize-autoloader

# Config Apache
RUN sed -i 's!/var/www/html!/var/www/html/docroot!g' /etc/apache2/sites-available/000-default.conf \
    && echo "ServerName localhost" >> /etc/apache2/apache2.conf

# Permissions
RUN chown -R www-data:www-data /var/www/html/docroot/sites/default /var/www/html/config \
    && chmod -R 775 /var/www/html/docroot/sites/default /var/www/html/config

COPY ["./init.sh", "/init.sh"]
RUN chmod +x /init.sh

EXPOSE 80
ENTRYPOINT ["/init.sh"]
CMD ["apache2-foreground"]
