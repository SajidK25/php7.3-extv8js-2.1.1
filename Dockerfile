FROM ubuntu:18.04

ENV DEBIAN_FRONTEND=noninteractive

RUN   apt-get update 
RUN   apt-get install -y software-properties-common   language-pack-en-base sed
RUN   LC_ALL=en_US.UTF-8 add-apt-repository ppa:ondrej/php

# add PPA
RUN add-apt-repository ppa:stesie/libv8 -y; \
    apt-get update

# install PHP
# RUN apt-get install -y php7.3-common php7.3-{fpm,cli,common,apcu,mbstring,pdo,xml,curl,bcmath,mysql,redis,sqlite3,zip,geoip,dev}
RUN apt-get update && apt-get install -yq --no-install-recommends \
    apt-utils \
    curl \
    # Install git
    git \
    # Install apache
    apache2 \
    # Install php 7.3
    libapache2-mod-php7.3 \
    php7.3-cli \
    php7.3-json \
    php7.3-curl \
    php7.3-fpm \
    php7.3-gd \
    php7.3-ldap \
    php7.3-mbstring \
    php7.3-mysql \
    php7.3-soap \
    php7.3-sqlite3 \
    php7.3-xml \
    php7.3-zip \
    php7.3-intl \
    php-imagick \
    php7.3-GD \
    php7.3-bcmath \
    # Install tools
    openssl \
    nano \
    graphicsmagick \
    imagemagick \
    ghostscript \
    mysql-client \
    iputils-ping \
    locales \
    sqlite3 \
    ca-certificates \
    && apt-get clean && rm -rf /var/lib/apt/lists/*
    
# install v8
# library is installed to /opt/libv8-7.5
# it's implrtant to install both libv8-7.5 and libv8-7.5-dev, 
# because if you skip libv8-7.5-dev then you'll get error in next step:
# error: could not find libv8_libplatform library

RUN apt-get install -y libv8-7.5 libv8-7.5-dev

# install v8js
RUN printf "\/opt/libv8-7.5\n" | CFLAGS=-w CPPFLAGS=-w pecl install v8js-2.1.1

# enable php extension
RUN echo "extension = v8js.so" | tee -a /etc/php/7.3/mods-available/v8js.ini \
    phpenmod v8js

# check extension loaded (should output 'v8js')
CMD php -m | grep v8js