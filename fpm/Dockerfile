FROM ubuntu:focal
ARG PROXY

ADD oracle.tar.gz  /opt/oracle/
WORKDIR /var/www/html
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get -y install php7.4-fpm \
    php7.4-ldap \
    php7.4-mysql \
    php7.4-cli \
    php7.4-intl  \
    php7.4-curl \
#Oracle
    php7.4-dev \
    php7.4-zip \
    git libaio1 && \
    echo "\nlisten =  9000;" >> /etc/php/7.4/fpm/pool.d/www.conf && \
#Oracle
    if [ "$PROXY" = "1" ]; then pear config-set http_proxy http://proxy.univ-lyon1.fr:3128; fi && \
    echo 'instantclient,/opt/oracle/instantclient_21_4' | pecl install oci8-2.2.0 && \
    echo 'extension=oci8.so' > /etc/php/7.4/fpm/conf.d/30-oci8.ini && \
    echo 'extension=oci8.so' > /etc/php/7.4/cli/conf.d/30-oci8.ini
COPY docker-entrypoint.sh /usr/bin
EXPOSE 9000

    #ln -s /opt/oracle/instantclient_12_2/libclntsh.so.12.1 /opt/oracle/instantclient_12_2/libclntsh.so && \
    #ln -s /opt/oracle/instantclient_12_2/libocci.so.12.1 /opt/oracle/instantclient_12_2/libocci.so && \
    #libaio1  &&\
