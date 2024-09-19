#/bin/bash

#
# Restore DB and Files from S3 with Restic locally
#
# Usage:
# SITE_ORIGINAL_URL=https://www.epfl.ch/campus/services/website/canari/ SITE_ANSIBLE_IDENTIFIER=www__campus__services__website__canari RESTORED_SITE_DIR_NAME=canari ./local-restore-from-restic.sh
#

# TODO:
#  - ensure that everythings is here (keybase, restic, etc.)
#  - improve wp-veritas to be able to fetch `ansibleHost` with a query
#

set -e -x

scriptdir="$(dirname "$0")"
export $(cat ${scriptdir}/../.env | grep WP_ENV=)
_mgmt_container="$(docker ps -q --filter "label=ch.epfl.wordpress.mgmt.env=${WP_ENV}")"

SITE_ORIGINAL_URL="${SITE_ORIGINAL_URL:-https://www.epfl.ch/campus/services/website/canari/}"
SITE_ANSIBLE_IDENTIFIER="${SITE_ANSIBLE_IDENTIFIER:-www__campus__services__website__canari}"
RESTORED_SITE_DIR_NAME="${RESTORED_SITE_DIR_NAME:-canari}"
S3_BUCKET_NAME="${S3_BUCKET_NAME:-svc0041-b80382f4fba20c6c1d9dc1bebefc5583}"

export AWS_DEFAULT_REGION=us-east-1 # This is the default
# Retrieve AWS_SECRET_ACCESS_KEY, AWS_ACCESS_KEY_ID and RESTIC_PASSWORD from keybase
export AWS_SECRET_ACCESS_KEY=$(cat /keybase/team/epfl_wp_prod/aws-cli-credentials | grep -A2 '\[backup-wwp\]' | grep aws_secret_access_key | sed 's/aws_secret_access_key = //')
export AWS_ACCESS_KEY_ID=$(cat /keybase/team/epfl_wp_prod/aws-cli-credentials | grep -A2 '\[backup-wwp\]' | grep aws_access_key_id | sed 's/aws_access_key_id = //')
export RESTIC_PASSWORD=$(cat /keybase/team/epfl_wp_prod/aws-cli-credentials | grep -A3 '\[backup-wwp\]' | grep restic_password | sed 's/restic_password = //')

# Get the latest DB backup from S3
restic -r s3:https://s3.epfl.ch/${S3_BUCKET_NAME}/backup/wordpresses/${SITE_ANSIBLE_IDENTIFIER}/sql dump latest db-backup.sql > ${scriptdir}/../volumes/srv/${WP_ENV}/${SITE_ANSIBLE_IDENTIFIER}-db-backup.sql

# Create the empty dir for the new site
docker exec --user www-data -i ${_mgmt_container} bash -c "mkdir -p /srv/${WP_ENV}/wp-httpd/htdocs/${RESTORED_SITE_DIR_NAME}"

# Initilialize the new site
docker exec --user www-data -i ${_mgmt_container} bash -c "cd /srv/${WP_ENV}/wp-httpd/htdocs/${RESTORED_SITE_DIR_NAME}; new-wp-site --debug"

# Restore the backup directly in the new site's folder
restic -r s3:https://s3.epfl.ch/${S3_BUCKET_NAME}/backup/wordpresses/${SITE_ANSIBLE_IDENTIFIER}/files dump latest /wp-content \
   | docker exec --user www-data -i ${_mgmt_container} tar -C/srv/${WP_ENV}/wp-httpd/htdocs/${RESTORED_SITE_DIR_NAME} -xpvf -

# Import the DB
docker exec --user www-data -i ${_mgmt_container} bash -c "wp --path=/srv/${WP_ENV}/wp-httpd/htdocs/${RESTORED_SITE_DIR_NAME} db import /srv/${WP_ENV}/${SITE_ANSIBLE_IDENTIFIER}-db-backup.sql"

# Ensure that URLs are correct with search-replace
#  - see https://stackoverflow.com/a/9018877/960623 for the ${DIR%/} that remove the trailing slash
docker exec --user www-data -i ${_mgmt_container} bash -c "wp --path=/srv/${WP_ENV}/wp-httpd/htdocs/${RESTORED_SITE_DIR_NAME} search-replace ${SITE_ORIGINAL_URL%/} https://wp-httpd/${RESTORED_SITE_DIR_NAME%/}"

# Set the admin password to "secret"
docker exec --user www-data -i ${_mgmt_container} bash -c "wp --path=/srv/${WP_ENV}/wp-httpd/htdocs/${RESTORED_SITE_DIR_NAME} user update admin --user_pass=secret"
