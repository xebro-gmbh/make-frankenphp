FROM dunglas/frankenphp:1.12.4-php8.5 AS base

ENV TZ=Europe/Berlin
ENV HISTFILE=/app/.bash_history

RUN DEBIAN_FRONTEND=noninteractive \
    apt-get update -q \
    && DEBIAN_FRONTEND=noninteractive apt-get install -qq -y \
      curl \
      git \
      gosu \
      libpng-dev \
      libjpeg-dev \
      libfreetype-dev \
      rsync \
      tzdata \
      unzip \
      zip

RUN install-php-extensions \
      amqp \
      bz2 \
      gd \
      intl \
      opcache \
      pcntl \
      pdo_pgsql \
      pgsql \
      redis \
      xml \
      zip

ADD config/php.ini /usr/local/etc/php/conf.d/888-php-prod.ini
ADD config/Caddyfile /etc/frankenphp/Caddyfile

# Set timezone to Berlin
RUN ln -fs /usr/share/zoneinfo/$TZ /etc/localtime \
    && dpkg-reconfigure -f noninteractive tzdata

RUN mkdir -p {/app,/data/caddy,/config}
RUN chmod -R 0777 /data
RUN chmod -R 0755 /config

WORKDIR /app


FROM base AS base_prod


FROM base AS base_ci

COPY --from=composer:2 /usr/bin/composer /usr/bin/composer


FROM base AS dev

ENV COMPOSER_HOME=/composer_data
ENV COMPOSER_CACHE_DIR=/composer

RUN install-php-extensions xdebug

RUN mkdir -p ${COMPOSER_HOME} ; \
    mkdir -p ${COMPOSER_CACHE_DIR}

ADD ./config/install_composer.sh /var/scripts/
RUN chmod +x /var/scripts/install_composer.sh ; /var/scripts/install_composer.sh
RUN chmod -R 0755 ${COMPOSER_HOME}

ADD config/Caddyfile.dev /etc/frankenphp/Caddyfile
ADD config/php-dev.ini /usr/local/etc/php/conf.d/999-php-dev.ini
