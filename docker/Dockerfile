#FROM php:7.4.2-apache
FROM php:7.0.33-apache

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        net-tools \
        git \
        clamav clamav-daemon \
        vim sed
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
RUN service clamav-freshclam stop
RUN freshclam
RUN service clamav-freshclam start

# install browscap.ini and modify php.ini setting to point to it
RUN mkdir -p /usr/local/etc/php/extra/ \
    && curl "http://browscap.org/stream?q=PHP_BrowsCapINI" \
    -o /usr/local/etc/php/extra/browscap.ini
RUN sed -i '/browscap =/c\browscap = /usr/local/etc/php/extra/browscap.ini' /usr/local/etc/php/php.ini-development
RUN echo "[browscap]" > /usr/local/etc/php/conf.d/docker-php-browscap.ini
RUN echo "browscap = /usr/local/etc/php/extra/browscap.ini" >> /usr/local/etc/php/conf.d/docker-php-browscap.ini


# enable the mod_ssl module in apache and configure it for HTTPS
RUN a2enmod rewrite
RUN service apache2 restart
RUN a2enmod ssl

# install SSL certificate and key as per /etc/apache2/sites-available/default-ssl.conf
COPY config/ssl-cert-snakeoil.pem /etc/ssl/certs/
COPY config/ssl-cert-snakeoil.key /etc/ssl/private/

# sendmail config
############################################

RUN apt-get install -q -y ssmtp mailutils

# root is the person who gets all mail for userids < 1000
RUN echo "root=dmcd2356@gmail.com" >> /etc/ssmtp/ssmtp.conf
RUN echo "host=localhost" >> /etc/ssmtp/ssmtp.conf

# Here is the gmail configuration (or change it to your private smtp server)
RUN echo "mailhub=smtp.gmail.com:587" >> /etc/ssmtp/ssmtp.conf
RUN echo "AuthUser=cmcd3457@gmail.com" >> /etc/ssmtp/ssmtp.conf
RUN echo "AuthPass=ihdfpfzhgbdwwbea" >> /etc/ssmtp/ssmtp.conf

RUN echo "UseTLS=YES" >> /etc/ssmtp/ssmtp.conf
RUN echo "UseSTARTTLS=YES" >> /etc/ssmtp/ssmtp.conf
RUN echo "FromLineOverride=YES" >> /etc/ssmtp/ssmtp.conf

# Set up php sendmail config
RUN echo "sendmail_path=sendmail -i -t" >> /usr/local/etc/php/conf.d/docker-php-sendmail.ini
############################################

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
