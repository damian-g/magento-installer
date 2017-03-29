#!/bin/bash

# Check if the MAGENTO_ROOT directory has been specified
if [ -z "$MAGENTO_ROOT" ]; then
	echo "Please specify the root directory of Magento via the environment variable: MAGENTO_ROOT"
	exit 1
fi

# Check if there is already an local.xml. If yes, abort the installation process.
if [ ! -f "$MAGENTO_ROOT/app/etc/local.xml" ]; then
    databaseFilePath="/tmp/sql/*.gz"

    # Check if database dump file exist
    if [ ! -f $databaseFilePath ]; then
        echo "Please include dump of database in ./resources/sql/ as 'gzip' file (.gz)"
        exit 1
    fi

    echo "Preparing the Magerun Configuration"
    substitute-env-vars.sh /etc /etc/n98-magerun.yaml.tmpl

    echo "Preparing the Magento Configuration"
    substitute-env-vars.sh /etc /etc/local.xml.tmpl

    echo "Overriding Magento Configuration"
    cp -v /etc/local.xml $MAGENTO_ROOT/app/etc/local.xml

    until mysql -h "$MYSQL_HOST" -u "$MYSQL_USER" -p"$MYSQL_PASSWORD" -e ";" ; do
           echo "Database has not been opened yet, trying to reconnect in 10 seconds"

           sleep 10
    done

    echo "Database is up and ready"

    echo "Magerun: Importing database"
    magerun --skip-root-check --root-dir="$MAGENTO_ROOT" db:create
    magerun --skip-root-check --root-dir="$MAGENTO_ROOT" db:import --compression="gzip" $databaseFilePath

    echo "Magerun: Delete all admin users"
    magerun --skip-root-check --root-dir="$MAGENTO_ROOT" \
            db:query 'SET FOREIGN_KEY_CHECKS = 0; TRUNCATE TABLE admin_user; TRUNCATE TABLE api2_acl_user; SET FOREIGN_KEY_CHECKS = 1;'

    echo "Magerun: Create admin user"
    magerun --skip-root-check --root-dir="$MAGENTO_ROOT" \
            admin:user:create \
            "${ADMIN_USERNAME}" \
            "${ADMIN_EMAIL}" \
            "${ADMIN_PASSWORD}" \
            "${ADMIN_FIRSTNAME}" \
            "${ADMIN_LASTNAME}" \
            "Administrators"

    echo "Magerun: Clear base url and cookie data"
    magerun --skip-root-check --root-dir="$MAGENTO_ROOT" config:delete --all web/unsecure/base_url
    magerun --skip-root-check --root-dir="$MAGENTO_ROOT" config:delete --all web/unsecure/base_link_url
    magerun --skip-root-check --root-dir="$MAGENTO_ROOT" config:delete --all web/unsecure/base_skin_url
    magerun --skip-root-check --root-dir="$MAGENTO_ROOT" config:delete --all web/unsecure/base_media_url
    magerun --skip-root-check --root-dir="$MAGENTO_ROOT" config:delete --all web/unsecure/base_js_url
    magerun --skip-root-check --root-dir="$MAGENTO_ROOT" config:delete --all web/secure/base_url
    magerun --skip-root-check --root-dir="$MAGENTO_ROOT" config:delete --all web/secure/base_link_url
    magerun --skip-root-check --root-dir="$MAGENTO_ROOT" config:delete --all web/secure/base_skin_url
    magerun --skip-root-check --root-dir="$MAGENTO_ROOT" config:delete --all web/secure/base_media_url
    magerun --skip-root-check --root-dir="$MAGENTO_ROOT" config:delete --all web/secure/base_js_url
    magerun --skip-root-check --root-dir="$MAGENTO_ROOT" config:delete --all web/cookie/domain_path
    magerun --skip-root-check --root-dir="$MAGENTO_ROOT" config:delete --all web/cookie/cookie_domain

    echo "Magerun: Add Store Code to Urls"
    magerun --skip-root-check --root-dir="$MAGENTO_ROOT" config:delete --all web/url/use_store
    magerun --skip-root-check --root-dir="$MAGENTO_ROOT" config:set web/url/use_store 1

    echo "Magerun: Reindex"
    magerun --skip-root-check --root-dir="$MAGENTO_ROOT" index:reindex:all

    echo "Magerun: Disable cache"
    magerun --skip-root-check --root-dir="$MAGENTO_ROOT" cache:disable
    magerun --skip-root-check --root-dir="$MAGENTO_ROOT" cache:clean
fi

echo "Fixing filesystem permissions"
chmod -R go+rw $MAGENTO_ROOT

echo "Page is up!"
echo "http://$DOMAIN"

exit 0