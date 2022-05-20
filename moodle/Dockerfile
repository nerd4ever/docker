# Dockerfile for Moodle instance with Postgres.
FROM php:7.4-apache
LABEL maintainer="Nerd4ever Desenvolvimento Tecnlógico e Inovação Ltda <repo@nerd4ever.com.br>"

ENV TZ=UTC
ENV MOODLE_EMAIL_ADDRESS='ead@localhost'
ARG DEBIAN_FRONTEND=noninteractive
# persistent dependencies
RUN set -eux; \
	apt-get update; \
	apt-get install -y --no-install-recommends \
# Ghostscript is required for rendering PDF previews
		ghostscript \
		dos2unix \
		acl \
	; \
	rm -rf /var/lib/apt/lists/*

# install the PHP extensions we need (https://docs.moodle.org/311/en/PHP)
RUN set -ex; \
	\
	savedAptMark="$(apt-mark showmanual)"; \
	\
	apt-get update; \
	apt-get install -y --no-install-recommends \
		libfreetype6-dev \
		libicu-dev \
		libjpeg-dev \
		libmagickwand-dev \
		libpng-dev \
		libwebp-dev \
		libzip-dev \
		libpq-dev \
		libxml2-dev \
		ntp \
	; \
	\
	docker-php-ext-configure gd \
		--with-freetype \
		--with-jpeg \
		--with-webp \
	; \
	docker-php-ext-install -j "$(nproc)" \
      	bcmath \
		exif \
		gd \
		intl \
		mysqli \
		zip \
		pgsql \
		pdo \
		pdo_pgsql \
		soap \
		xmlrpc \
		; 
RUN \
# https://pecl.php.net/package/imagick
	pecl install imagick-3.6.0; \
	docker-php-ext-enable imagick; \
	rm -r /tmp/pear; 
# set recommended PHP.ini settings
# see https://secure.php.net/manual/en/opcache.installation.php
RUN set -eux; \
	docker-php-ext-enable opcache; \
	{ \
		echo 'opcache.memory_consumption=128'; \
		echo 'opcache.interned_strings_buffer=8'; \
		echo 'opcache.max_accelerated_files=4000'; \
		echo 'opcache.revalidate_freq=2'; \
		echo 'opcache.fast_shutdown=1'; \
	} > /usr/local/etc/php/conf.d/opcache-recommended.ini
# https://wordpress.org/support/article/editing-wp-config-php/#configure-error-logging
RUN { \
# https://www.php.net/manual/en/errorfunc.constants.php
# https://github.com/docker-library/wordpress/issues/420#issuecomment-517839670
		echo 'error_reporting = E_ERROR | E_WARNING | E_PARSE | E_CORE_ERROR | E_CORE_WARNING | E_COMPILE_ERROR | E_COMPILE_WARNING | E_RECOVERABLE_ERROR'; \
		echo 'display_errors = Off'; \
		echo 'display_startup_errors = Off'; \
		echo 'log_errors = On'; \
		echo 'error_log = /dev/stderr'; \
		echo 'log_errors_max_len = 1024'; \
		echo 'ignore_repeated_errors = On'; \
		echo 'ignore_repeated_source = Off'; \
		echo 'html_errors = Off'; \
	} > /usr/local/etc/php/conf.d/error-logging.ini; \
	{\
		echo 'max_input_vars = 5000'; \
	} > /usr/local/etc/php/conf.d/10-moodle.ini; \
    { \
    # https://docs.moodle.org/19/en/PHP_settings_by_Moodle_version
		echo 'safe_mode = Off'; \
		echo 'session.save_handler = FILES'; \
		echo 'magic_quotes_gpc = Off'; \
		echo 'magic_quotes_runtime = Off'; \
		echo 'file_uploads = ON'; \
		echo 'session.auto_start = Off'; \
		echo 'session.bug_compat_warn = Off'; \
	} > /usr/local/etc/php/conf.d/moodle.ini
RUN set -eux; \
	a2enmod rewrite expires; \
	\
# https://httpd.apache.org/docs/2.4/mod/mod_remoteip.html
	a2enmod remoteip; \
	{ \
		echo 'RemoteIPHeader X-Forwarded-For'; \
# these IP ranges are reserved for "private" use and should thus *usually* be safe inside Docker
		echo 'RemoteIPTrustedProxy 10.0.0.0/8'; \
		echo 'RemoteIPTrustedProxy 172.16.0.0/12'; \
		echo 'RemoteIPTrustedProxy 192.168.0.0/16'; \
		echo 'RemoteIPTrustedProxy 169.254.0.0/16'; \
		echo 'RemoteIPTrustedProxy 127.0.0.0/8'; \
	} > /etc/apache2/conf-available/remoteip.conf; \
	a2enconf remoteip; \
# https://github.com/docker-library/wordpress/issues/383#issuecomment-507886512
# (replace all instances of "%h" with "%a" in LogFormat)
	find /etc/apache2 -type f -name '*.conf' -exec sed -ri 's/([[:space:]]*LogFormat[[:space:]]+"[^"]*)%h([^"]*")/\1%a\2/g' '{}' +

RUN set -eux; \
	version='4.0.1'; \
	sha256='127f3b7b9ad595082f4d14b31b329264fdb35833b979438cb229c827c15ca15f'; \
	\
	curl -o moodle.tar.tgz -fL "https://download.moodle.org/download.php/direct/stable400/moodle-$version.tgz"; \
	echo "$sha256 moodle.tar.tgz" | sha256sum -c -; \
	\
# upstream tarballs include ./moodle/ so this gives us /usr/src/moodle
	mkdir -p /usr/src/moodle/; \
	mkdir -p /usr/src/moodle/moodledata; \
	tar -zxvf moodle.tar.tgz -C /usr/src/moodle/; \
	mv -f /usr/src/moodle/moodle /usr/src/moodle/public; \
	rm moodle.tar.tgz; \
	\
# https://wordpress.org/support/article/htaccess/
	[ ! -e /usr/src/moodle/.htaccess ]; \
	{ \
		echo '# BEGIN Moodle'; \
		echo ''; \
		echo 'RewriteEngine On'; \
		echo 'RewriteRule .* - [E=HTTP_AUTHORIZATION:%{HTTP:Authorization}]'; \
		echo 'RewriteBase /'; \
		echo 'RewriteRule ^index\.php$ - [L]'; \
		echo 'RewriteCond %{REQUEST_FILENAME} !-f'; \
		echo 'RewriteCond %{REQUEST_FILENAME} !-d'; \
		echo 'RewriteRule . /index.php [L]'; \
		echo ''; \
		echo '# END Moodle'; \
	} > /usr/src/moodle/.htaccess; \
	\
	chown -R www-data:www-data /usr/src/moodle; \
	chmod -R 777 /usr/src/moodle/moodledata; \
	unlink /etc/apache2/sites-enabled/000-default.conf

VOLUME /var/www/html

COPY moodle.conf /etc/apache2/sites-enabled/moodle.conf
RUN sed -i "s/{{emailAddress}}/${MOODLE_EMAIL_ADDRESS}/g" /etc/apache2/sites-enabled/moodle.conf

COPY entrypoint.sh /entrypoint
RUN dos2unix /entrypoint \
    && chmod +x /entrypoint

VOLUME ["/var/www"]
EXPOSE 80

CMD ["/entrypoint", "daemon"]