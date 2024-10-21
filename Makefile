.PHONY: all
all: checkout up

include .env

-include .make.vars

# Auto-detected variables (computed once and stored until "make clean")
.make.vars: docker-compose.yml Makefile
	@echo "# Auto-generated by Makefile, DO NOT EDIT" > $@
# Figure out whether we clone over https or git+ssh (you need a GitHub
# account set up with an ssh public key for the latter)
	@echo _GITHUB_BASE = $(if $(shell ssh -T git@github.com 2>&1|grep 'successful'),git@github.com:,https://github.com/) >> $@
	@echo _DOCKER_PULLED_IMAGES = $(shell cat docker-compose.yml | grep 'image: ' | grep -v default.svc | cut -d: -f2-) >> $@
	@echo _DOCKER_BUILT_IMAGES = $(DOCKER_BASE_IMAGE_NAME) $(shell cat docker-compose.yml | grep 'image: ' | grep default.svc | cut -d: -f2-) >> $@
	@echo _DOCKER_BASE_IMAGE_DEPS = $(shell find wp-ops/docker/wp-base -type f | sed 's/\n/ /g') >> $@
	@echo _DOCKER_MGMT_IMAGE_DEPS = $(shell find wp-ops/docker/mgmt -type f | sed 's/\n/ /g') >> $@
	@echo _DOCKER_NGINX_IMAGE_DEPS = $(shell find wp-ops/docker/nginx -type f | sed 's/\n/ /g') >> $@
	@echo _HOST_TAR_X = $(shell if [ "$$(uname -s)" = "Linux" ]; then echo "tar -m --overwrite" ; else echo tar; fi) >> $@

m = $(notdir $(MAKE))
.PHONY: help
help:
	@echo 'Usage:'
	@echo
	@echo '$(m) help           Show this message'
	@echo
	@echo '$(m) checkout       Checkout wp-ops, WP Thems and Plugins. Use'
	@echo '                        make checkout MINIMAL=1'
	@echo "                    for a minimal version that doesn't need ISAS-FSD accesses"
	@echo
	@echo '$(m) up             Start up a local WordPress instance'
	@echo '                    with docker compose for development.'
	@echo '                    Be sure to review ../README.md for'
	@echo '                    preliminary steps (entry in /etc/hosts,'
	@echo '                    .env file and more)'
	@echo
	@echo '$(m) gutenberg      Start the building and Hotserver for Gutenberg developments'
	@echo
	@echo '$(m) stop           Stop the development environment'
	@echo '$(m) down           Bring down the development environment'
	@echo '$(m) clean'
	@echo
	@echo '$(m) exec           Enter the management container'
	@echo '$(m) nginx          Enter the nginx container'
	@echo '$(m) mysql          Enter the MySQL container'
	@echo
	@echo '$(m) lnav           Improved error logs compilation through the terminal'
	@echo "$(m) tail-access    Follow the tail of Apache's access resp."
	@echo '$(m) tail-errors    error logs through the terminal'
	@echo
	@echo '$(m) tail-sql       Activate and follow the MySQL general'
	@echo '                    query log'
	@echo
	@echo '$(m) pull           Refresh the Docker images'
	@echo '$(m) clean-images   Prune the Docker images'
	@echo '$(m) docker-build   Build the Docker images'
	@echo
	@echo '$(m) backup         Backup the whole state (incl. MySQL)'
	@echo '                    to wordpress-state.tgz'
	@echo '$(m) restore        Restore from wordpress-state.tgz'
	@echo
	@echo '$(m) vars           Summarize the vars from the dot env file'

# Default values, can be overridden either on the command line of make
# or in .env
WP_ENV ?= your-env
WP_PORT_HTTP ?= 80
WP_PORT_HTTPS ?= 443

DOCKER_IMAGE_STAMPS = .docker-images-pulled.stamp \
  .docker-base-image-built.stamp \
  .docker-all-images-built.stamp

DOCKER_BASE_IMAGE_NAME = docker-registry.default.svc:5000/wwp-test/wp-base
DOCKER_NGINX_IMAGE_NAME = docker-registry.default.svc:5000/wwp-test/nginx
DOCKER_MGMT_IMAGE_NAME = docker-registry.default.svc:5000/wwp-test/mgmt

WP_MAJOR_VERSION = 6
WP_CONTENT_DIR = volumes/wp/$(WP_MAJOR_VERSION)/wp-content
WP_CLI_DIR = volumes/wp/wp-cli/vendor/epfl-si/wp-cli
POLYLANG_CLI_DIR = volumes/wp/wp-cli/vendor/epfl-si/polylang-cli

CTAGS_TARGETS = volumes/wp/$(WP_MAJOR_VERSION)/*.php \
  volumes/wp/$(WP_MAJOR_VERSION)/wp-admin \
  volumes/wp/$(WP_MAJOR_VERSION)/wp-includes \
  $(WP_CONTENT_DIR)/themes/wp-theme-2018 \
  $(WP_CONTENT_DIR)/plugins/epfl-* \
  $(WP_CONTENT_DIR)/plugins/polylang \
  $(WP_CONTENT_DIR)/mu-plugins

_mgmt_container = `docker ps -q --filter "label=ch.epfl.wordpress.mgmt.env=$(WP_ENV)"`
_nginx_container = `docker ps -q --filter "label=ch.epfl.wordpress.nginx.env=$(WP_ENV)"`

_docker_exec_mgmt := docker exec --user www-data -it \
	  -e WP_ENV=$(WP_ENV) \
	  -e MARIADB_ROOT_PASSWORD=$(MARIADB_ROOT_PASSWORD) \
	  -e MYSQL_DB_HOST=$(MYSQL_DB_HOST) \
	  $(_mgmt_container)

.PHONY: vars
vars:
	@echo 'Environment-related vars:'
	@echo '  WP_ENV=$(WP_ENV)'
	@echo '  _mgmt_container=$(_mgmt_container)'
	@echo '  _nginx_container=$(_nginx_container)'
	@echo '  CTAGS_TARGETS=$(CTAGS_TARGETS)'

	@echo ''
	@echo DB-related vars:
	@echo '  MARIADB_ROOT_PASSWORD=$(MARIADB_ROOT_PASSWORD)'
	@echo '  MYSQL_DB_HOST=$(MYSQL_DB_HOST)'
	@echo '  MYSQL_SUPER_USER=$(MYSQL_SUPER_USER)'
	@echo '  MYSQL_SUPER_PASSWORD=$(MYSQL_SUPER_PASSWORD)'

	@echo ''
	@echo 'Wordpress-related vars:'
	@echo '  WP_VERSION=$(WP_VERSION)'
	@echo '  WP_ADMIN_USER=$(WP_ADMIN_USER)'
	@echo '  WP_ADMIN_EMAIL=$(WP_ADMIN_EMAIL)'
	@echo '  WP_PORT_HTTP=$(WP_PORT_HTTP)'
	@echo '  WP_PORT_HTTPS=$(WP_PORT_HTTPS)'

	@echo ''
	@echo 'WPManagement-related vars:'
	@echo '  WP_PORT_PHPMA=$(WP_PORT_PHPMA)'
	@echo '  WP_PORT_SSHD=$(WP_PORT_SSHD)'

######################## Pulling code ##########################
#
# As a matter of taste, we'd rather have Makefile-driven `git clone`s
# than submodules - Plus this lets you substitute your own arrangement
# if you wish.
#
# Code doesn't only get pulled from git either: volumes/wp is extracted
# from the "nginx" Docker image, and we create a couple of symlinks too.

.PHONY: checkout
checkout: \
  $(WP_CONTENT_DIR) \
  $(WP_CONTENT_DIR)/plugins/accred \
  $(WP_CONTENT_DIR)/plugins/tequila \
  $(WP_CONTENT_DIR)/plugins/enlighter \
  $(WP_CONTENT_DIR)/plugins/epfl-menus \
  $(WP_CONTENT_DIR)/themes/wp-theme-2018 \
  $(WP_CONTENT_DIR)/themes/wp-theme-light \
  $(WP_CONTENT_DIR)/plugins/wp-gutenberg-epfl \
  $(WP_CONTENT_DIR)/plugins/epfl-404 \
  $(WP_CONTENT_DIR)/plugins/EPFL-settings \
  $(WP_CONTENT_DIR)/plugins/epfl-scienceqa \
  $(WP_CONTENT_DIR)/plugins/EPFL-Content-Filter \
  $(WP_CONTENT_DIR)/plugins/epfl-intranet \
  $(WP_CONTENT_DIR)/plugins/epfl-restauration \
  $(WP_CONTENT_DIR)/plugins/EPFL-Library-Plugins \
  $(WP_CONTENT_DIR)/plugins/epfl-cache-control \
  $(WP_CONTENT_DIR)/plugins/epfl-remote-content-shortcode \
  $(WP_CONTENT_DIR)/plugins/epfl-emploi \
  $(WP_CONTENT_DIR)/plugins/epfl-courses-se \
  $(WP_CONTENT_DIR)/plugins/epfl-coming-soon \
  $(WP_CONTENT_DIR)/plugins/wpforms-epfl-payonline \
  $(WP_CONTENT_DIR)/plugins/epfl-diploma-verification \
  $(WP_CONTENT_DIR)/mu-plugins \
  $(WP_CLI_DIR) \
  $(POLYLANG_CLI_DIR) \
  menu-api \
  wp-ops \
  wp-operator \
  volumes/usrlocalbin

git_clone = mkdir -p $(dir $@) || true; devscripts/ensure-git-clone.sh $(_GITHUB_BASE)$(strip $(1)) $@; touch $@

volumes/usrlocalbin: .docker-all-images-built.stamp
	mkdir -p $@ || true
	docker run --rm --name volumes-usrlocalbin-extractor \
	  --entrypoint /bin/bash \
	  $(DOCKER_MGMT_IMAGE_NAME) \
	  -c "tar -C/usr/local/bin --exclude=new-wp-site -clf - ." \
	  | $(_HOST_TAR_X) -Cvolumes/usrlocalbin -xpvf -
	rm -f volumes/usrlocalbin/new-wp-site
	(echo '#!/bin/sh'); echo 'exec /wp-ops/docker/mgmt/new-wp-site.sh "$@"' > volumes/usrlocalbin/new-wp-site
	chmod 755 volumes/usrlocalbin/new-wp-site
	touch $@

$(WP_CONTENT_DIR): .docker-all-images-built.stamp
	-rm -f `find $(WP_CONTENT_DIR)/plugins \
	             $(WP_CONTENT_DIR)/themes \
	             $(WP_CONTENT_DIR)/mu-plugins -type l`
	mkdir -p volumes || true
	docker run --rm --name volumes-wp-extractor \
	  --entrypoint /bin/bash \
	  $(DOCKER_NGINX_IMAGE_NAME) \
	  -c "tar -clf - --exclude=/wp/*/wp-content/themes/{wp-theme-2018,wp-theme-light} \
	                 --exclude=/wp/*/wp-content/plugins/{accred,tequila,enlighter,*epfl*,*EPFL*} \
	                 --exclude=/wp/*/wp-content/mu-plugins \
	                 --exclude=/wp/nginx-entrypoint \
	            /wp; sleep 10" \
	  | $(_HOST_TAR_X) -Cvolumes -xpf - wp
# Excluded directories --exclude= above) are replaced with a git
# checkout of same (next few targets below).
	touch $@

$(WP_CONTENT_DIR)/plugins:
	@mkdir -p $(dir $@) || true

$(WP_CONTENT_DIR)/plugins/accred: $(WP_CONTENT_DIR)
	$(call git_clone, epfl-si/wordpress.plugin.accred)

$(WP_CONTENT_DIR)/plugins/tequila: $(WP_CONTENT_DIR)
	$(call git_clone, epfl-si/wordpress.plugin.tequila)

$(WP_CONTENT_DIR)/plugins/wp-gutenberg-epfl: $(WP_CONTENT_DIR)
	$(call git_clone, epfl-si/wp-gutenberg-epfl)

$(WP_CONTENT_DIR)/themes/wp-theme-2018.git: $(WP_CONTENT_DIR)
	$(call git_clone, epfl-si/wp-theme-2018.git)

$(WP_CONTENT_DIR)/themes/wp-theme-2018: $(WP_CONTENT_DIR)/themes/wp-theme-2018.git
	ln -sf wp-theme-2018.git/wp-theme-2018 $@

$(WP_CONTENT_DIR)/themes/wp-theme-light: $(WP_CONTENT_DIR)/themes/wp-theme-2018.git
	ln -sf wp-theme-2018.git/wp-theme-light $@

$(WP_CONTENT_DIR)/plugins/epfl-menus: $(WP_CONTENT_DIR)
	$(call git_clone, epfl-si/wp-plugin-epfl-menus)

$(WP_CONTENT_DIR)/plugins/epfl-404: $(WP_CONTENT_DIR)
	$(call git_clone, epfl-si/wp-plugin-epfl-404)

$(WP_CONTENT_DIR)/plugins/EPFL-settings: $(WP_CONTENT_DIR)
	$(call git_clone, epfl-si/wp-plugin-epfl-settings)

$(WP_CONTENT_DIR)/plugins/epfl-scienceqa: $(WP_CONTENT_DIR)
	$(call git_clone, epfl-si/wp-plugin-epfl-scienceqa)

$(WP_CONTENT_DIR)/plugins/EPFL-Content-Filter: $(WP_CONTENT_DIR)
	$(call git_clone, epfl-si/wp-plugin-epfl-content-filter)

$(WP_CONTENT_DIR)/plugins/epfl-intranet: $(WP_CONTENT_DIR)
	$(call git_clone, epfl-si/wp-plugin-epfl-intranet)

$(WP_CONTENT_DIR)/plugins/epfl-restauration: $(WP_CONTENT_DIR)
	$(call git_clone, epfl-si/wp-plugin-epfl-restauration)

$(WP_CONTENT_DIR)/plugins/EPFL-Library-Plugins: $(WP_CONTENT_DIR)
	$(call git_clone, epfl-si/wp-plugin-epfl-library)

$(WP_CONTENT_DIR)/plugins/enlighter: $(WP_CONTENT_DIR)
	$(call git_clone, epfl-si/wp-plugin-enlighter)

$(WP_CONTENT_DIR)/plugins/epfl-cache-control: $(WP_CONTENT_DIR)
	$(call git_clone, epfl-si/wp-plugin-epfl-cache-control)

$(WP_CONTENT_DIR)/plugins/epfl-remote-content-shortcode: $(WP_CONTENT_DIR)
	$(call git_clone, epfl-si/wp-plugin-epfl-remote-content)

$(WP_CONTENT_DIR)/plugins/epfl-emploi: $(WP_CONTENT_DIR)
	$(call git_clone, epfl-si/wp-plugin-epfl-emploi)

$(WP_CONTENT_DIR)/plugins/epfl-courses-se: $(WP_CONTENT_DIR)
	$(call git_clone, epfl-si/wp-plugin-epfl-courses-se)

$(WP_CONTENT_DIR)/plugins/epfl-coming-soon: $(WP_CONTENT_DIR)
	$(call git_clone, epfl-si/wp-plugin-epfl-coming-soon)

$(WP_CONTENT_DIR)/plugins/wpforms-epfl-payonline: $(WP_CONTENT_DIR)
	$(call git_clone, epfl-si/wpforms-epfl-payonline)

$(WP_CONTENT_DIR)/mu-plugins: $(WP_CONTENT_DIR)
	$(call git_clone, epfl-si/wp-mu-plugins)

$(WP_CLI_DIR):
	$(call git_clone, epfl-si/wp-cli)

$(POLYLANG_CLI_DIR):
	$(call git_clone, epfl-si/polylang-cli)

$(WP_CONTENT_DIR)/plugins/epfl-diploma-verification: $(WP_CONTENT_DIR)
	$(call git_clone, epfl-si/wp-plugin-epfl-diploma-verification)

$(WP_CONTENT_DIR)/plugins/epfl-partner-universities: $(WP_CONTENT_DIR)
	$(call git_clone, epfl-si/wp-plugin-epfl-partner-universities)

wp-ops:
	$(call git_clone, epfl-si/wp-ops)
	cd wp-ops; git checkout WPN
	$(MAKE) -C wp-ops checkout

menu-api:
	$(call git_clone, epfl-si/wp-menu-api)

wp-operator:
	$(call git_clone, epfl-si/wp-operator)
	cd wp-operator; git checkout WPN


################ Building or pulling Docker images ###############

.PHONY: pull
pull:
	rm -f .docker-images-pulled.stamp
	$(MAKE) .docker-images-pulled.stamp

.docker-images-pulled.stamp: docker-compose.yml
	for image in $(_DOCKER_PULLED_IMAGES); do docker pull $$image; done
	touch $@

ifdef MINIMAL
_DEFAULT_INSTALL_AUTO_FLAGS := --exclude=wp-media-folder --exclude=wpforms --exclude=wpforms-surveys-polls
else
_DEFAULT_INSTALL_AUTO_FLAGS = $(_S3_INSTALL_AUTO_FLAGS)   # Below
endif

_S3_KEYBASE_TEAM_DIR := /keybase/team/epfl_wp_test
_S3_SUITCASE_EYAML_PATH := $(shell pwd)/wp-ops/ansible/ansible-deps-cache/bin
_S3_SECRETS_PATH := wp-ops/ansible/roles/wordpress-openshift-namespace/vars/secrets-wwp-test.yml
_s3_secrets_build_query = $(shell perl -ne 'if (m/^build:/) { $$skipping = 0; } elsif (m/^[a-z]/) { $$skipping = 1; }; next if $$skipping; print if s/^\s*$(1): //' < $(_S3_SECRETS_PATH))

_S3_INSTALL_AUTO_FLAGS = \
   --s3-endpoint-url=$(call _s3_secrets_build_query,endpoint_url) \
   --s3-region=$(call _s3_secrets_build_query,region) \
   --s3-key-id=$(call _s3_secrets_build_query,key_id) \
   --s3-bucket-name=$(call _s3_secrets_build_query,bucket_name) \
   --s3-secret=$(shell export PATH=$(_S3_SUITCASE_EYAML_PATH):$$PATH; \
      env EYAML_PRIVKEY="$$(keybase fs read $(_S3_KEYBASE_TEAM_DIR)/eyaml-privkey.pem)" \
          EYAML_PUBKEY="$$(keybase fs read $(_S3_KEYBASE_TEAM_DIR)/eyaml-pubkey.pem)" \
      eyaml decrypt \
            --pkcs7-private-key-env-var EYAML_PRIVKEY \
            --pkcs7-public-key-env-var EYAML_PUBKEY \
            -s "$(call _s3_secrets_build_query,secret)")

.debug.s3:
	-@echo $(_S3_INSTALL_AUTO_FLAGS)

.docker-base-image-built.stamp: wp-ops $(_DOCKER_BASE_IMAGE_DEPS)
	@if PATH=$(_S3_SUITCASE_EYAML_PATH):$$PATH which eyaml; then : ; else \
	  echo >&2 "eyaml command needed to decipher build-time secrets."; \
	  echo >&2 "Please either install ruby and the hiera-eyaml gem,"; \
	  echo >&2 "or deploy your Ansible suitcase: "; \
	  echo >&2 ; \
	  echo >&2 "   ./wp-ops/ansible/wpsible -t nothing"; \
	fi

	[ -d wp-ops/docker/wp-base ] && \
	  docker build -t $(DOCKER_BASE_IMAGE_NAME) $(DOCKER_BASE_BUILD_ARGS) --build-arg INSTALL_AUTO_FLAGS="$(INSTALL_AUTO_FLAGS) $(_DEFAULT_INSTALL_AUTO_FLAGS)" wp-ops/docker/wp-base
	touch $@

.docker-all-images-built.stamp: .docker-base-image-built.stamp wp-ops \
                                 $(_DOCKER_NGINX_IMAGE_DEPS)
	docker compose build $(DOCKER_BUILD_ARGS)
	touch $@

.PHONY: docker-build
docker-build:
	rm -f .docker*built.stamp
	$(MAKE) .docker-all-images-built.stamp

.PHONY: clean-images
clean-images:
	for image in $(_DOCKER_PULLED_IMAGES) $(_DOCKER_BUILT_IMAGES); do docker rmi $$image || true; done
	docker image prune
	rm -f .docker*.stamp

######################## Development Lifecycle #####################

SITE_DIR := /srv/test/wp-httpd/htdocs

.PHONY: up
up: checkout $(DOCKER_IMAGE_STAMPS) volumes/srv/test
	$(source_smtp_secrets); \
	docker compose up -d
	./devscripts/await-mariadb-ready
	$(MAKE) rootsite
	@echo "If you have want to use the wp-gutenberg-epfl plugin or to dev on Gutenberg,"
	@echo "install nvm and run 'make gutenberg'"

nvm:
	. ${NVM_DIR}/nvm.sh && nvm install 20;

.PHONY: gutenberg
gutenberg:
	$(MAKE) nvm
	cd $(WP_CONTENT_DIR)/plugins/wp-gutenberg-epfl; npm install --silent --no-fund; npm start

.PHONY: rootsite
rootsite:
	@$(_docker_exec_mgmt) bash -c 'wp --path=$(SITE_DIR) eval "1;"' ||      \
	  $(_docker_exec_mgmt) bash -c '                                        \
	    set -e -x;                                                          \
	    mkdir -p $(SITE_DIR) || true;                                       \
	    cd $(SITE_DIR);                                                     \
	    export WORDPRESS_VERSION=$(WP_MAJOR_VERSION); new-wp-site --debug;  \
	    for subdir in plugins mu-plugins; do                                \
	      if [ ! -e wp-content/$$subdir ]; then                             \
	        ln -sfn ../wp/wp-content/$$subdir wp-content/$$subdir;          \
	      fi;                                                               \
	    done;                                                               \
	    mkdir -p $(SITE_DIR)/wp-content/themes;                             \
	    for subtheme in wp-theme-2018 wp-theme-light; do                    \
	      if [ ! -e wp-content/themes/$$subtheme ]; then                    \
	        ln -sfn ../../wp/wp-content/themes/wp-theme-2018.git/$$subtheme \
	        wp-content/themes/$$subtheme;                                   \
	      fi;                                                               \
	    done;                                                               \
	    wp theme activate wp-theme-2018;                                    \
	    wp user update admin --user_pass=secret;                            \
	    '

.PHONY: stop
stop:
	docker compose stop

.PHONY: down
down:
	docker compose down

_find_git_depots := find . \( -path ./volumes/srv -prune -false \) -o -name .git -prune |xargs -n 1 dirname|grep -v 'ansible-deps-cache'
.PHONY: gitstatus
gitstatus:
	@set -e; for dir in `$(_find_git_depots)`; do (cd $$dir; echo "$$(tput bold)$$dir$$(tput sgr0)"; git status -uno; echo); done

.PHONY: gitpull
gitpull:
	@set -e; for dir in `$(_find_git_depots)`; do (cd $$dir; echo "$$(tput bold)$$dir$$(tput sgr0)"; git pull --rebase --autostash; echo); done

volumes/srv/test:
	mkdir -p "$@"
	chmod 1777 "$@"

# SMTP secret
define source_smtp_secrets
	eval $$(keybase fs read /keybase/team/epfl_wp_test/service-noreply-wwp.sh|grep SMTP_SECRET) ; \
	export SMTP_SECRET
endef

######################## Development Tasks ########################

.PHONY: exec
exec:
	@$(_docker_exec_mgmt) bash -l

.PHONY: mysql
mysql:
	@$(_docker_exec_mgmt) bash -c 'mysql -p$$MARIADB_ROOT_PASSWORD -u root -h db'

.PHONY: nginx
nginx:
	@docker exec -it $(_nginx_container) bash -l

.PHONY: tail-errors
tail-errors:
	tail -F volumes/srv/*/logs/error_log.*.`date +%Y%m%d`

.PHONY: tail-access
tail-access:
	tail -F volumes/srv/*/logs/access_log.*.`date +%Y%m%d`

.PHONY: logs
logs:
	docker compose logs -f --tail=5

.PHONY: lnav
lnav:
	@$(_docker_exec_mgmt) bash -c 'lnav /srv/*/logs'

.PHONY: tail-sql
tail-sql:
	./devscripts/mysql-general-log tail

CTAGS_FLAGS = --exclude=node_modules $(EXTRA_CTAGS_FLAGS) -R $(CTAGS_TARGETS)
tags: checkout
	ctags $(CTAGS_FLAGS)

TAGS: checkout
	ctags -e $(CTAGS_FLAGS)

.phony: backup
backup:
	./devscripts/backup-restore backup wordpress-state.tgz

.phony: restore
restore:
	./devscripts/backup-restore restore wordpress-state.tgz

######################## Cleaning up ##########################

.PHONY: clean
clean: down clean-images
	rm -f .make.vars TAGS tags

.PHONY: mrproper
mrproper: clean
	rm -rf volumes/wp
