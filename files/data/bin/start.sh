#!/bin/sh
# (C) Campbell Software Solutions 2015
set -e

# Populate "/data/upload/include/i18n" volume with language packs
if [ ! "$(ls -A /data/upload/include/i18n)" ]; then
    cp -r /data/upload/include/i18n.dist/* /data/upload/include/i18n
    chown -R www-data:www-data /data/upload/include/i18n
fi

# Automate installation
php /data/bin/install.php
echo Applying configuration file security
chmod 644 /data/upload/include/ost-config.php

mkdir -p /run/nginx
chown -R www-data:www-data /run/nginx
chown -R www-data:www-data /var/lib/nginx
mkdir -p /var/log/php
chown -R www-data:www-data /var/log/php

# Add Time Tracking mod from robintoy - assumes database already modified

#wget -O /tmp/file.zip https://github.com/osTicket/osTicket/files/2845027/osTicket_v1.11-TimeTracking_Mod.zip
#unzip /tmp/file.zip -d /tmp
#cp -a /tmp/osTicket_v1.11-TimeTracking_Mod/include/* /data/upload/include/
#cp -a /tmp/osTicket_v1.11-TimeTracking_Mod/scp/* /data/upload/scp/

#Launch supervisor to manage processes
exec /usr/bin/supervisord -c /data/supervisord.conf
