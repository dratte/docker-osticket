# syntax=docker/dockerfile:1
#
# osTicket 1.17.8 + enhancement patch, on a PHP build that fixes
# CVE-2026-109618 / CVE-2026-109619 ("PHP2Shell", released 2026-10-21).
#
# Fixed PHP releases: 8.2.35, 8.3.36, 8.4.27, 8.5.12. PHP 8.0 (used before)
# is end-of-life and gets no fix. osTicket 1.17.8 supports PHP 8.1-8.4.
# 8.3 is what the enhancement patch was tested on; 8.4 is osTicket's
# recommendation. Change with:  docker build --build-arg PHP_VERSION=8.4.27 .
ARG PHP_VERSION=8.3.36
 
# ---------------------------------------------------------------------------
# Deployment doesn't work on Alpine
FROM php:${PHP_VERSION}-cli AS deployer
ENV OSTICKET_VERSION=1.18.4
COPY patches/osticket-enhancements.patch /tmp/osticket-enhancements.patch
RUN set -x \
    && apt-get update \
    && apt-get install -y --no-install-recommends git ca-certificates \
    && git clone -b v${OSTICKET_VERSION} --depth 1 https://github.com/osTicket/osTicket.git \
    && cd osTicket \
    # Apply the enhancement patch (fails the build if the patch doesn't fit)
    && git apply --check /tmp/osticket-enhancements.patch \
    && git apply /tmp/osticket-enhancements.patch \
    && php manage.php deploy -sv /data/upload \
    # www-data is uid:gid 82:82 in php:*-fpm-alpine
    && chown -R 82:82 /data/upload \
    # Hide setup
    && mv /data/upload/setup /data/upload/setup_hidden \
    && chown -R root:root /data/upload/setup_hidden \
    && chmod -R go= /data/upload/setup_hidden
 
# ---------------------------------------------------------------------------
FROM php:${PHP_VERSION}-fpm-alpine
ARG PHP_VERSION
LABEL maintainer="Dave Ratte <daveinpalmbay@gmail.com>"
# environment for osticket
ENV HOME=/data
# setup workdir
WORKDIR /data
COPY --from=deployer /data/upload upload
 
# Refuse to build on a PHP that is missing the 2026-10-21 security fix
RUN php -r '$fixed = ["8.2" => "8.2.35", "8.3" => "8.3.36", "8.4" => "8.4.27", "8.5" => "8.5.12"]; $b = PHP_MAJOR_VERSION . "." . PHP_MINOR_VERSION; if (!isset($fixed[$b]) || version_compare(PHP_VERSION, $fixed[$b], "<")) { fwrite(STDERR, "PHP " . PHP_VERSION . " lacks the CVE-2026-109618/109619 fix\n"); exit(1); }' \
    && php -v
 
# Runtime packages
RUN apk add --no-cache \
        wget \
        msmtp \
        ca-certificates \
        supervisor \
        nginx \
        libpng \
        libzip \
        libldap \
        libintl \
        libxml2 \
        icu-libs \
        openssl
 
# PHP extensions. curl, xml, mbstring, iconv, ctype, json, dom, phar are
# built into the official image. imap is no longer needed: osTicket 1.17
# fetches mail with Laminas-Mail (and ext-imap left PHP core in 8.4).
# linux-headers is required to build "sockets" on PHP 8.3+.
RUN set -eux; \
    apk add --no-cache --virtual .build-deps \
        $PHPIZE_DEPS \
        linux-headers \
        libpng-dev \
        libzip-dev \
        openldap-dev \
        gettext-dev \
        libxml2-dev \
        icu-dev \
        pcre-dev; \
    docker-php-ext-install -j"$(nproc)" gd; \
    docker-php-ext-install -j"$(nproc)" ldap mysqli gettext intl opcache zip; \
    docker-php-ext-install -j"$(nproc)" sockets; \
    pecl install apcu; \
    docker-php-ext-enable apcu; \
    apk del .build-deps; \
    rm -rf /var/cache/apk/* /tmp/pear; \
    php -m
 
RUN set -x && \
    # Download languages packs
    wget -nv -O upload/include/i18n/fr.phar https://s3.amazonaws.com/downloads.osticket.com/lang/fr.phar && \
    wget -nv -O upload/include/i18n/ar.phar https://s3.amazonaws.com/downloads.osticket.com/lang/ar.phar && \
    wget -nv -O upload/include/i18n/pt_BR.phar https://s3.amazonaws.com/downloads.osticket.com/lang/pt_BR.phar && \
    wget -nv -O upload/include/i18n/it.phar https://s3.amazonaws.com/downloads.osticket.com/lang/it.phar && \
    wget -nv -O upload/include/i18n/es_ES.phar https://s3.amazonaws.com/downloads.osticket.com/lang/es_ES.phar && \
    wget -nv -O upload/include/i18n/de.phar https://s3.amazonaws.com/downloads.osticket.com/lang/de.phar && \
    mv upload/include/i18n upload/include/i18n.dist && \
    # Download LDAP plugin
    wget -nv -O upload/include/plugins/auth-ldap.phar https://s3.amazonaws.com/downloads.osticket.com/plugin/auth-ldap.phar && \
    chown 82:82 upload/include/plugins/auth-ldap.phar && \
    # Keep a copy of the image's plugins (enhancement plugins + LDAP). The
    # plugins folder is a volume, so an existing volume hides new plugin
    # files; start.sh copies this folder into the volume on every start.
    cp -a upload/include/plugins upload/include/plugins.dist && \
    # Create msmtp log
    touch /var/log/msmtp.log && \
    chown www-data:www-data /var/log/msmtp.log
    # File upload permissions
    # chown nginx:www-data /var/tmp/nginx && chmod g+rx /var/tmp/nginx
 
COPY files/ /
VOLUME ["/data/upload/include/plugins","/data/upload/include/i18n"]
EXPOSE 80
CMD ["/data/bin/start.sh"]

