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
	@echo _DOCKER_BUILT_IMAGES = wp-base $(shell cat docker-compose.yml | grep 'image: ' | grep default.svc | cut -d: -f2-) >> $@
	@echo _WPBASE_IMAGE_DEPS = $(shell find wp-ops/docker/wp-base -type f | sed 's/\n/ /g') >> $@
	@echo _HOST_TAR_X = $(shell if [ "$$(uname -s)" = "Linux" ]; then echo "tar -m --overwrite" ; else echo tar; fi) >> $@
	@keybase fs read /keybase/team/epfl_wp_test/s3-assets-credentials.sh >> $@
	@if ! grep AWS_ACCESS_KEY_ID $@ > /dev/null; then \
	   echo >&2 "##############################################################" ;    \
	   echo >&2 "#" ;                                                                 \
	   echo >&2 "# WARNING: keybase failure; built Docker images" ;                   \
	   echo >&2 "# will be missing the plugins hosted on EPFL's Scality S3" ;         \
	   echo >&2 "# servers." ;                                                        \
	   echo >&2 "#" ;                                                                 \
	   echo >&2 "# Assuming you have access to these, please review the error" ;      \
	   echo >&2 "# messages above to troubleshoot." ;                                 \
	   echo >&2 "#" ;                                                                 \
	   echo >&2 "##############################################################" ;    \
	   echo >&2 "Press Return to continue:" ;                                         \
	   read;                                                                          \
	 fi


.PHONY: help
help: ## Display this help.
# The '##@' marker creates sections in the help  message, and '##' at the end
# of the name of a rule (after its dependencies, if any) documents it.
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m<target>\033[0m\n"} /^[a-zA-Z_0-9-]+:.*?##/ { printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)

# Default values, can be overridden either on the command line of make
# or in .env
WP_ENV ?= your-env
WP_PORT_HTTP ?= 80
WP_PORT_HTTPS ?= 443

DOCKER_IMAGE_STAMPS = .docker-images-pulled.stamp \
  .docker-base-image-built.stamp \
  .docker-all-images-built.stamp

WP_MAJOR_VERSION = 6
WP_CONTENT_DIR = volumes/wp/$(WP_MAJOR_VERSION)/wp-content
WP_CLI_DIR = volumes/wp/wp-cli/vendor/epfl-si/wp-cli
POLYLANG_CLI_DIR = volumes/wp/wp-cli/vendor/epfl-si/polylang-cli

_mgmt_container = `docker ps -q --filter "label=ch.epfl.wordpress.mgmt.env=$(WP_ENV)"`
_nginx_container = `docker ps -q --filter "label=ch.epfl.wordpress.nginx.env=$(WP_ENV)"`

_docker_exec_mgmt := docker exec --user www-data -it \
	  -e WP_ENV=$(WP_ENV) \
	  -e MARIADB_ROOT_PASSWORD=$(MARIADB_ROOT_PASSWORD) \
	  -e MYSQL_DB_HOST=$(MYSQL_DB_HOST) \
	  $(_mgmt_container)

######################## Pulling code ##########################
#
# As a matter of taste, we'd rather have Makefile-driven `git clone`s
# than submodules - Plus this lets you substitute your own arrangement
# if you wish.
#
# Code doesn't only get pulled from git either: volumes/wp is extracted
# from the "nginx" Docker image, and we create a couple of symlinks too.

.PHONY: checkout
checkout: ## Checkout wp-ops, WP Thems and Plugins
	$(MAKE) .checkout

.checkout: \
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
  wp-operator

git_clone = mkdir -p $(dir $@) || true; devscripts/ensure-git-clone.sh $(_GITHUB_BASE)$(strip $(1)) $@; touch $@

$(WP_CONTENT_DIR): .docker-all-images-built.stamp
	-rm -f `find $(WP_CONTENT_DIR)/plugins \
	             $(WP_CONTENT_DIR)/themes \
	             $(WP_CONTENT_DIR)/mu-plugins -type l`
	mkdir -p volumes || true
	docker run --rm --name volumes-wp-extractor \
	  --entrypoint /bin/bash \
	  wp-base \
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

.PHONY: menu-api
menu-api:
	$(call git_clone, epfl-si/wp-menu-api)

wp-ops/ansible/ansible-deps-cache/bin/eyaml: wp-ops
	./wp-ops/ansible/wpsible -t nothing

.PHONY: wp-operator
wp-operator:
	$(call git_clone, epfl-si/wp-operator)
	cd wp-operator; git checkout main

.PHONY: wpn
wpn: ## Build wp-base then wp-nginx and wp-php and push them
ifeq ($(VER),)
	$(error Need a value for VER, e.g., make wpn VER=001)
endif

	set -e -x; \
	echo "Build wp-nginx:2025-$(VER) & wp-php:2025-$(VER)" ; \
	docker build -t wp-base \
		--build-arg AWS_ACCESS_KEY_ID=$$AWS_ACCESS_KEY_ID \
		--build-arg AWS_SECRET_ACCESS_KEY=$$AWS_SECRET_ACCESS_KEY \
		wp-ops/docker/wp-base ; \
	docker build -t quay-its.epfl.ch/svc0041/wp-nginx:2025-$(VER) \
		wp-ops/docker/wordpress-nginx ; \
	docker build -t quay-its.epfl.ch/svc0041/wp-php:2025-$(VER) \
		wp-ops/docker/wordpress-php ; \
	docker push quay-its.epfl.ch/svc0041/wp-nginx:2025-$(VER) ; \
	docker push quay-its.epfl.ch/svc0041/wp-php:2025-$(VER) ; \
	echo "Now's probably a good time to run ./ansible/wpsible -t wp.web"


################ Building or pulling Docker images ###############

.PHONY: pull
pull:  ## Refresh the Docker images
	rm -f .docker-images-pulled.stamp
	$(MAKE) .docker-images-pulled.stamp

.docker-images-pulled.stamp: docker-compose.yml
	for image in $(_DOCKER_PULLED_IMAGES); do docker pull $$image; done
	touch $@

ifndef MINIMAL
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

.docker-base-image-built.stamp: wp-ops/ansible/ansible-deps-cache/bin/eyaml $(_WPBASE_IMAGE_DEPS))
	[ -d wp-ops/docker/wp-base ] && \
	  docker build -t wp-base $(WPBASE_BUILD_ARGS) --build-arg INSTALL_AUTO_FLAGS="$(INSTALL_AUTO_FLAGS) $(_DEFAULT_INSTALL_AUTO_FLAGS)" wp-ops/docker/wp-base
	touch $@

.docker-all-images-built.stamp: .docker-base-image-built.stamp wp-ops
	docker compose build $(DOCKER_BUILD_ARGS)
	touch $@

.PHONY: docker-build
docker-build:  ## Build the Docker images locally
	rm -f .docker*built.stamp
	$(MAKE) .docker-all-images-built.stamp

.PHONY: clean-images
clean-images:  ## Prune the Docker images
	for image in $(_DOCKER_PULLED_IMAGES) $(_DOCKER_BUILT_IMAGES); do docker rmi $$image || true; done
	docker image prune
	rm -f .docker*.stamp

######################## Development Lifecycle #####################

SITE_DIR := /srv/test/wp-httpd/htdocs

.PHONY: up
up: checkout $(DOCKER_IMAGE_STAMPS) volumes/srv/test  ## Start up a local WordPress instance
	$(source_smtp_secrets); \
	docker compose up -d
	./devscripts/await-mariadb-ready
	$(MAKE) rootsite
	@echo "If you have want to use the wp-gutenberg-epfl plugin or to dev on Gutenberg,"
	@echo "install nvm and run 'make gutenberg'"

nvm:
	. ${NVM_DIR}/nvm.sh && nvm install 20;

.PHONY: gutenberg
gutenberg:  ## Start the development server for Gutenberg
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
stop:  ## Stop the local WordPress instance
	docker compose stop

.PHONY: down
down:  ## Stop the local WordPress instance and delete its containers
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
exec:  ## Enter the management container
	@$(_docker_exec_mgmt) bash -l

.PHONY: mysql
mysql:  ## Run a MySQL command-line client
	@$(_docker_exec_mgmt) bash -c 'mysql -p$$MARIADB_ROOT_PASSWORD -u root -h db'

.PHONY: nginx
nginx:  ## Enter the nginx container
	@docker exec -it $(_nginx_container) bash -l

.PHONY: tail-errors
tail-errors:  ## Follow the Apache error log
	tail -F volumes/srv/*/logs/error_log.*.`date +%Y%m%d`

.PHONY: tail-access
tail-access:  ## Follow the Apache access log
	tail -F volumes/srv/*/logs/access_log.*.`date +%Y%m%d`

.PHONY: logs
logs:
	docker compose logs -f --tail=5

.PHONY: lnav
lnav:
	@$(_docker_exec_mgmt) bash -c 'lnav /srv/*/logs'

.PHONY: tail-sql
tail-sql:  ## Activate and follow the MySQL general query log
	./devscripts/mysql-general-log tail

########################################################################
##@ Developer Support

CTAGS_FLAGS = --exclude=node_modules $(EXTRA_CTAGS_FLAGS) -R $(CTAGS_TARGETS)

CTAGS_TARGETS = volumes/wp/$(WP_MAJOR_VERSION)/*.php \
  volumes/wp/$(WP_MAJOR_VERSION)/wp-admin \
  volumes/wp/$(WP_MAJOR_VERSION)/wp-includes \
  $(WP_CONTENT_DIR)/themes/wp-theme-2018 \
  $(WP_CONTENT_DIR)/plugins/epfl-* \
  $(WP_CONTENT_DIR)/plugins/polylang \
  $(WP_CONTENT_DIR)/mu-plugins

tags: checkout  ## Index the source code in vim format
	ctags $(CTAGS_FLAGS)

TAGS: checkout  ## Index the source code in Emacs ”etags” format
	ctags -e $(CTAGS_FLAGS)

.phony: backup
backup:
	./devscripts/backup-restore backup wordpress-state.tgz

.phony: restore
restore:
	./devscripts/backup-restore restore wordpress-state.tgz

########################################################################
##@ Cleanup

.PHONY: clean
clean: down clean-images  ## Prune the Docker images
	rm -f .make.vars TAGS tags

.PHONY: mrproper
mrproper: clean
	rm -rf volumes/wp
