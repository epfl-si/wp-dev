#!/bin/sh

scriptdir="$(dirname "$0")"

docker_mgmt_cmd () {
    if [ -z "$_mgmt_container" ]; then
        _mgmt_container="$(. "$scriptdir"/../.env; docker ps -q --filter "label=ch.epfl.wordpress.mgmt.env=${WP_ENV}")"
    fi
    docker exec -i --user www-data "$_mgmt_container" bash -c "$*"
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

wp_admin_password_admin () {
    local site="$1"
    docker_mgmt_cmd "$(cat <<SET_ADMIN_PASSWORD
set -e -x
cd /srv/test/wp-httpd/htdocs/$site
wp user update admin --user_pass=admin
SET_ADMIN_PASSWORD
)"
}


## Debug mode ?
echo ""
echo -n "Do you want to activate debug mode on the loaded sites (y/n)?"
read answer

# TODO: make this flexible (split $1, reverse)
if [ "$answer" != "${answer#[Yy]}" ] ;then
    for site in "" schools schools/enac schools/enac/education ; do
        wp_debug_mode_activate "$site"
    done
fi

## Without tequila ?
echo ""
echo -n "Do you want to desactivate Tequila feature on the loaded sites (user/password will be admin/admin) (y/n)?"
read answer

# TODO: make this flexible (split $1, reverse)
if [ "$answer" != "${answer#[Yy]}" ] ;then
    for site in "" schools schools/enac schools/enac/education ; do
        wp_tequila_desactivation "$site"
        wp_admin_password_admin  "$site"
    done
fi
