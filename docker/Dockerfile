#FROM php:7.4.2-apache
FROM php:7.0.33-apache

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        net-tools \
        git \
        clamav clamav-daemon \
        vim
RUN docker-php-ext-install mysqli pdo pdo_mysql
RUN docker-php-ext-install sockets
RUN apt-get install -y \
        libfreetype6-dev \
        libjpeg62-turbo-dev \
        libpng-dev \
# for php:7.4:
#    && docker-php-ext-configure gd --with-freetype=/usr/include/ --with-jpeg=/usr/include/ \
# for php:7.0:
 && docker-php-ext-configure gd --with-freetype-dir=/usr/include/ --with-jpeg-dir=/usr/include/ \
 && docker-php-ext-install -j$(nproc) gd
RUN docker-php-ext-configure opcache --enable-opcache \
 && docker-php-ext-install opcache

# increase memory limit (default is 128M)
RUN echo 'memory_limit = 1024M' >> /usr/local/etc/php/conf.d/docker-php-memlimit.ini;

# install uploadprogress for drupal
RUN git clone https://github.com/php/pecl-php-uploadprogress/ /usr/src/php/ext/uploadprogress/ \
 && docker-php-ext-configure uploadprogress \
 && docker-php-ext-install uploadprogress \
 && rm -rf /usr/src/php/ext/uploadprogress

# update the ClamAV database
RUN service clamav-daemon stop
RUN freshclam

# enable the mod_ssl module in apache and configure it for HTTPS
RUN a2enmod rewrite
RUN service apache2 restart
RUN a2enmod ssl

# install SSL certificate and key as per /etc/apache2/sites-available/default-ssl.conf
COPY config/ssl-cert-snakeoil.pem /etc/ssl/certs/
COPY config/ssl-cert-snakeoil.key /etc/ssl/private/

# install the PHP configuration changes file
# (This doesn't seem to work, so now we just append the file to the /var/www/html/.htaccess file.
#  This is performed in start-drupal.sh)
#COPY config/zz-app.ini /usr/local/etc/php/conf.d/zz-app.ini

# copy the ClamAV config file to run on port 3310
COPY config/clamd.conf /etc/clamav/clamd.conf
RUN chmod 644 /etc/clamav/clamd.conf

# enable the default ssl site in apache
RUN a2ensite default-ssl

# start ClamAV service
RUN service clamav-daemon start

EXPOSE 443
