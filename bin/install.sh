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

    # Wait to allow database container fully start.
    # Sadly docker-compose don't support container dependencies yet
    echo "Wait 5 minutes ..."
    sleep 300
    echo "Wait is over!"

    echo "Magerun: Installing database"
    magerun --skip-root-check --root-dir="$MAGENTO_ROOT" db:create
    magerun --skip-root-check --root-dir="$MAGENTO_ROOT" db:import --compression="gzip" $databaseFilePath

    echo "Magerun: Delete admin user if exist"
    magerun --skip-root-check --root-dir="$MAGENTO_ROOT" \
            admin:user:delete \
            "${ADMIN_USERNAME}" -f

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

    echo "Magerun: Use English"
    magerun --skip-root-check --root-dir="$MAGENTO_ROOT" config:delete --all general/locale/code
    magerun --skip-root-check --root-dir="$MAGENTO_ROOT" config:set general/locale/code en_GB

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