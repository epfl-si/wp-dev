#!/bin/sh

WP_VERSION=5.2

set -e -x
scriptdir="$(dirname "$0")"

wp_export_prod() {
    ssh -X www-data@ssh-wwp.epfl.ch -p 32222 "cd /srv/www/www.epfl.ch/htdocs/$1; wp db export -"
}

docker_mgmt_cmd () {
    if [ -z "$_mgmt_container" ]; then
        _mgmt_container="$(. "$scriptdir"/../.env; docker ps -q --filter "label=ch.epfl.wordpress.mgmt.env=${WP_ENV}")"
    fi
    docker exec -i --user www-data "$_mgmt_container" bash -c "$*"
}

wp_import_docker() {
    local site="$1"
    docker_mgmt_cmd "set -e -x; cd /srv/test/wp-httpd/htdocs/$site; wp db import -"
}

wp_prepare () {
    local site="$1"
    docker_mgmt_cmd "$(cat <<CREATE_SITE_SCRIPT
set -e -x
mkdir -p /srv/test/wp-httpd/htdocs/$site || true
cd /srv/test/wp-httpd/htdocs/$site
/usr/local/bin/new-wp-site
rm wp
ln -s "/wp/$WP_VERSION" wp
CREATE_SITE_SCRIPT

cat <<'POPULATE_SITE_SCRIPT'
for symlinkdir in wp-content/plugins wp-content/mu-plugins wp-content/themes; do
    mkdir -p "$symlinkdir" || true
    rm -f "$symlinkdir"/*
    (cd "$symlinkdir"; ln -s ../../wp/"$symlinkdir"/* .)
done

POPULATE_SITE_SCRIPT
)"
}

wp_search_replace () {
    local site="$1"
    docker_mgmt_cmd "set -e -x; cd /srv/test/wp-httpd/htdocs/$site; wp search-replace https://www.epfl.ch http://wp-httpd"
}

wp_debug_mode_activate () {
    local site="$1"
    docker_mgmt_cmd "$(cat <<SET_DEBUG_WP_SITES
set -e -x
cd /srv/test/wp-httpd/htdocs/$site
wp config set WP_DEBUG true --raw --type=constant
wp config set WP_DEBUG_LOG true --raw --type=constant
wp config set WP_DEBUG_DISPLAY true --raw --type=constant
SET_DEBUG_WP_SITES
)"
}

wp_tequila_desactivation () {
    local site="$1"
    docker_mgmt_cmd "$(cat <<SET_AUTH_WITHOUT_ACCRED
set -e -x
cd /srv/test/wp-httpd/htdocs/$site
wp plugin deactivate tequila
wp plugin deactivate accred
SET_AUTH_WITHOUT_ACCRED
)"
}


# TODO: make this flexible (split $1, reverse)
for site in "" schools schools/enac schools/enac/education ; do
    wp_prepare "$site"
    wp_export_prod "$site" | wp_import_docker "$site"
    wp_search_replace "$site"
done
