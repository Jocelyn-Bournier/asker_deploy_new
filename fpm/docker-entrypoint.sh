#!/bin/bash
rm -Rf app/cache/*
rm -Rf app/logs/*
if [ $PROXY -eq 1 ];then
	export http_proxy=http://proxy.univ-lyon1.fr:3128
	export https_proxy=http://proxy.univ-lyon1.fr:3128
fi
chown www-data composer
chown www-data /var/www/html /var/www/ app/ web/
chown -R www-data app/* web/uploads
mkdir dir bin
chown www-data bin
chown  -R www-data var/
#php /var/www/html/composer install
su -s /bin/bash -c "php /var/www/html/composer install -n" www-data
echo "Asker is ready to use!"
/usr/sbin/php-fpm7.4 --nodaemonize
