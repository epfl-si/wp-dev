#/bin/bash

#
# Restore DB and Files from S3 with Restic locally
#
# Usage:
# SITE_ORIGINAL_URL=https://www.epfl.ch/campus/services/website/canari/ SITE_ANSIBLE_IDENTIFIER=www__campus__services__website__canari RESTORED_SITE_DIR_NAME=canari ./local-restore-from-restic.sh
#

# TODO
#  - manage secret in a better way (shell script?)
#  - ensure that everythings is here (keybase, restic, etc.)
#  - improve wp-veritas to be able to fetch `ansibleHost` with a query
#  - not chmod 777
#  - set the container name and/or query it (`wp-local-mgmt-1`)
#  - improve script args
#

set -e -x

SITE_ORIGINAL_URL="${SITE_ORIGINAL_URL:-https://www.epfl.ch/campus/services/website/canari/}"
SITE_ANSIBLE_IDENTIFIER="${SITE_ANSIBLE_IDENTIFIER:-www__campus__services__website__canari}"
RESTORED_SITE_DIR_NAME="${RESTORED_SITE_DIR_NAME:-canari}"

AWS_DEFAULT_REGION=us-east-1 # This is the default
# Retrieve AWS_SECRET_ACCESS_KEY, AWS_ACCESS_KEY_ID and RESTIC_PASSWORD from keybase
AWS_SECRET_ACCESS_KEY=$(cat /keybase/team/epfl_wp_prod/aws-cli-credentials | grep -A2 '\[backup-wwp\]' | grep aws_secret_access_key | sed 's/aws_secret_access_key = //')
AWS_ACCESS_KEY_ID=$(cat /keybase/team/epfl_wp_prod/aws-cli-credentials | grep -A2 '\[backup-wwp\]' | grep aws_access_key_id | sed 's/aws_access_key_id = //')
RESTIC_PASSWORD=$(cat /keybase/team/epfl_wp_prod/aws-cli-credentials | grep -A3 '\[backup-wwp\]' | grep restic_password | sed 's/restic_password = //')


# Get the latest DB backup from S3
restic -r s3:https://s3.epfl.ch/svc0041-df3298778888f91b2b62cf913f4c8c74/backup/wordpresses/${SITE_ANSIBLE_IDENTIFIER}/sql dump latest db-backup.sql > ../volumes/srv/test/${SITE_ANSIBLE_IDENTIFIER}-db-backup.sql

# Create the empty dir for the new site
docker exec --user www-data -i wp-local-mgmt-1 bash -c "mkdir -p /srv/test/wp-httpd/htdocs/${RESTORED_SITE_DIR_NAME}"

# Initilialize the new site
docker exec --user www-data -i wp-local-mgmt-1 bash -c "cd /srv/test/wp-httpd/htdocs/${RESTORED_SITE_DIR_NAME}; new-wp-site --debug"

# How to deal with local user right knowing that it's www-data in the container, this is very dirty
sudo chmod 777 -R ../volumes/srv/test/wp-httpd/htdocs/${RESTORED_SITE_DIR_NAME}/wp-content

# Restore the backup directly in the new site's folder
restic -r s3:https://s3.epfl.ch/svc0041-df3298778888f91b2b62cf913f4c8c74/backup/wordpresses/${SITE_ANSIBLE_IDENTIFIER}/files restore latest \
            --include="/wp-content" \
            --target ../volumes/srv/test/wp-httpd/htdocs/${RESTORED_SITE_DIR_NAME}/

# Import the DB
docker exec --user www-data -i wp-local-mgmt-1 bash -c "wp --path=/srv/test/wp-httpd/htdocs/${RESTORED_SITE_DIR_NAME} db import /srv/test/${SITE_ANSIBLE_IDENTIFIER}-db-backup.sql"

# Ensure that URLs are correct with serach-replace
docker exec --user www-data -i wp-local-mgmt-1 bash -c "wp --path=/srv/test/wp-httpd/htdocs/${RESTORED_SITE_DIR_NAME} search-replace ${SITE_ORIGINAL_URL} https://wp-httpd/${RESTORED_SITE_DIR_NAME}"

# Set the admin password to "secret"
docker exec --user www-data -i wp-local-mgmt-1 bash -c "wp --path=/srv/test/wp-httpd/htdocs/${RESTORED_SITE_DIR_NAME} user update admin --user_pass=secret"
