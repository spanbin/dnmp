#!/bin/bash

echo "============================================"
echo "Building extensions for $PHP_VERSION"
echo "============================================"


function phpVersion() {
    [[ ${PHP_VERSION} =~ ^([0-9]+)\.([0-9]+)\.([0-9]+) ]]
    num1=${BASH_REMATCH[1]}
    num2=${BASH_REMATCH[2]}
    num3=${BASH_REMATCH[3]}
    echo $[ $num1 * 10000 + $num2 * 100 + $num3 ]
}


version=$(phpVersion)
cd /tmp/extensions


# Use multicore compilation if php version greater than 5.4
if [ ${version} -ge 50600 ]; then
    export mc="-j$(nproc)";
fi


# Mcrypt was DEPRECATED in PHP 7.1.0, and REMOVED in PHP 7.2.0.
if [ ${version} -lt 70200 ]; then
    apt install -y libmcrypt-dev \
    && docker-php-ext-install $mc mcrypt
fi

# From PHP 5.6, we can use docker-php-ext-install to install opcache
if [ ${version} -lt 50600 ]; then
    mkdir zendopcache \
    && tar -xf zendopcache-7.0.5.tgz -C zendopcache --strip-components=1 \
    && ( cd zendopcache && phpize && ./configure && make $mc && make install ) \
    && docker-php-ext-enable opcache
else
    docker-php-ext-install opcache
fi

if [ "${PHP_REDIS}" != "false" ]; then
    mkdir redis \
    && tar -xf redis-${PHP_REDIS}.tgz -C redis --strip-components=1 \
    && ( cd redis && phpize && ./configure && make $mc && make install ) \
    && docker-php-ext-enable redis
fi


if [ "${PHP_XDEBUG}" != "false" ]; then
    mkdir xdebug \
    && tar -xf xdebug-${PHP_XDEBUG}.tgz -C xdebug --strip-components=1 \
    && ( cd xdebug && phpize && ./configure && make $mc && make install ) \
    && docker-php-ext-enable xdebug
fi


# swoole require PHP version 5.5 or later.
if [ "${PHP_SWOOLE}" != "false" ]; then
    mkdir swoole \
    && tar -xf swoole-${PHP_SWOOLE}.tgz -C swoole --strip-components=1 \
    && ( cd swoole && phpize && ./configure && make $mc && make install ) \
    && docker-php-ext-enable swoole
fi

# oci8.
if [ "${PHP_OCI8}" != "false" ]; then
    apt-get install -y alien libaio1 libaio-dev \
    && alien oracle-instantclient12.2-basic-12.2.0.1.0-1.x86_64.rpm \
    && alien oracle-instantclient12.2-devel-12.2.0.1.0-1.x86_64.rpm \
    && alien oracle-instantclient12.2-sqlplus-12.2.0.1.0-1.x86_64.rpm \
    && dpkg -i oracle-instantclient12.2-basic_12.2.0.1.0-2_amd64.deb \
    && dpkg -i oracle-instantclient12.2-devel_12.2.0.1.0-2_amd64.deb \
    && dpkg -i oracle-instantclient12.2-sqlplus_12.2.0.1.0-2_amd64.deb \
    && echo 'export ORACLE_HOME=/usr/lib/oracle/12.2/client64' >> /root/.bashrc \
    && echo 'export LD_LIBRARY_PATH=$ORACLE_HOME/lib' >> /root/.bashrc \
    && echo 'export TNS_ADMIN=$ORACLE_HOME/network/admin' >> /root/.bashrc \
    && echo 'export NLS_LANG="SIMPLIFIED CHINESE_CHINA.ZHS16GBK"' >> /root/.bashrc \
    && echo 'export PATH=$PATH:$ORACLE_HOME/bin:$ORACLE_HOME/lib' >> /root/.bashrc \
    && source /root/.bashrc \
    && echo '/usr/lib/oracle/12.2/client64/lib' > /etc/ld.so.conf.d/oracle.conf \
    && ldconfig \
    && ln -s /usr/lib/oracle/12.2/client64 /usr/lib/oracle/12.2/client \
    && ln -s /usr/include/oracle/12.2/client64 /usr/include/oracle/12.2/client \
    && echo 'instantclient,/usr/lib/oracle/12.2/client64/lib' | pecl install oci8-${PHP_OCI8} \
    && docker-php-ext-enable oci8

    # pdo_oci
    if [ ${version} -lt 60000 ]; then
        pecl install pdo_oci \
        && docker-php-ext-enable pdo_oci
    # PHP version 7.0 or later need source code
    else
        mkdir php-src \
        && tar -xf php-${PHP_VERSION}.tar.gz -C php-src \
        && (cd php-src/php-${PHP_VERSION}/ext/pdo_oci && phpize && ./configure --with-pdo-oci=instantclient,/usr/lib/oracle/12.2/client64/lib && make && make install) \
        && docker-php-ext-enable pdo_oci
    fi
fi

# sqlsrv pdo_sqlsrv require PHP version 7.0 or later.
if [ ${version} -gt 70000  ]; then
   apt install -y unixodbc-dev \
   && pecl install sqlsrv pdo_sqlsrv \
   && docker-php-ext-enable sqlsrv pdo_sqlsrv
fi

# memcached
apt install -y libmemcached-dev zlib1g-dev
if [ ${version} -lt 70000 ]; then
    pecl install memcached-2.2.0 \
    && docker-php-ext-enable memcached
else
    pecl install memcached \
    && docker-php-ext-enable memcached
fi

# memcache
if [ ${version} -lt 70000 ]; then
    pecl install memcache \
    && docker-php-ext-enable memcache
# PHP version 7.0 or later need form https://github.com/websupport-sk/pecl-memcache/releases
else
    tar -xf pecl-memcache-4.0.3.tar.gz \
    && (cd pecl-memcache-4.0.3 && phpize && ./configure && make && make install) \
    && docker-php-ext-enable memcache
fi