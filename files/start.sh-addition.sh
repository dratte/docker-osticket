# --- Add to files/data/bin/start.sh, before php-fpm / supervisord is started ---
#
# /data/upload/include/plugins is a Docker volume. When the volume already
# exists, Docker does NOT copy the image's new plugin files into it, so the
# patch plugins (and LDAP updates) would never appear. Copy them from the
# image on every start. Other plugins already in the volume are left alone.
if [ -d /data/upload/include/plugins.dist ]; then
    cp -a /data/upload/include/plugins.dist/. /data/upload/include/plugins/
fi
