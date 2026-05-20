FROM php:8.4-fpm AS builder

WORKDIR /app

RUN apt-get update && apt-get install -y \
    git \
    unzip \
    curl \
    nodejs \
    npm \
    && docker-php-ext-install pdo pdo_mysql \
    && rm -rf /var/lib/apt/lists/*

COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

ENV COMPOSER_ALLOW_SUPERUSER=1

COPY composer.json composer.lock ./

RUN composer install --no-interaction --no-scripts --optimize-autoloader

COPY . .

RUN if [ ! -f .env ]; then echo "APP_ENV=prod\nAPP_DEBUG=false\nAPP_SECRET=SomeRandomString" > .env; fi

RUN composer install --no-interaction --optimize-autoloader --no-ansi || true
RUN php bin/console importmap:install --no-interaction

RUN php bin/console cache:warmup --env=prod --no-debug || true

FROM php:8.4-fpm AS runtime

WORKDIR /app

RUN apt-get update && apt-get install -y \
    nginx \
    curl \
    && docker-php-ext-install pdo pdo_mysql \
    && rm -rf /var/lib/apt/lists/*

COPY --from=builder /app /app

RUN mkdir -p /app/var && \
    chown -R www-data:www-data /app && \
    chmod -R 755 /app && \
    chmod -R 775 /app/var

COPY nginx-main.conf /etc/nginx/nginx.conf
RUN rm -rf /etc/nginx/conf.d/* /etc/nginx/sites-enabled /etc/nginx/sites
COPY nginx.conf /etc/nginx/conf.d/symfony.conf

COPY entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

HEALTHCHECK --interval=10s --timeout=3s --start-period=10s --retries=3 \
    CMD curl -f http://localhost/ || exit 1

EXPOSE 80

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
