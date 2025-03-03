-include .env

-include .make.vars

# Auto-detected variables (computed once and stored until "make clean")
.make.vars: docker-compose.yml Makefile
	@echo "# Auto-generated by Makefile, DO NOT EDIT" > $@
# Figure out whether we clone over https or git+ssh (you need a GitHub
# account set up with an ssh public key for the latter)
	@echo _GITHUB_BASE = $(if $(shell ssh -T git@github.com 2>&1|grep 'successful'),git@github.com:,https://github.com/) >> $@
	@echo _HOST_TAR_X = $(shell if [ "$$(uname -s)" = "Linux" ]; then echo "tar -m --overwrite" ; else echo tar; fi) >> $@
	@keybase fs read /keybase/team/epfl_wp_test/s3-assets-credentials.sh >> $@
	@if ! grep AWS_ACCESS_KEY_ID $@ > /dev/null; then \
	  echo >&2 "##############################################################" ; \
	  echo >&2 "#" ;                                                              \
	  echo >&2 "# WARNING: keybase failure; built Docker images" ;                \
	  echo >&2 "# will be missing the plugins hosted on EPFL's Scality S3" ;      \
	  echo >&2 "# servers." ;                                                     \
	  echo >&2 "#" ;                                                              \
	  echo >&2 "# Assuming you have access to these, please review the error" ;   \
	  echo >&2 "# messages above to troubleshoot." ;                              \
	  echo >&2 "#" ;                                                              \
	  echo >&2 "##############################################################" ; \
	  echo >&2 "Press Return to continue:" ;                                      \
	  read;                                                                       \
	fi


.PHONY: help
help: ## Display this help
	@echo ""
	@echo "                   ┌──────────────────────────────────────┐"
	@echo "                   │                \033[1mwp-dev\033[0m                │"
	@echo "                   ├──────────────────────────────────────┤"
	@echo "                   │ Run a WordPress environment locally. │"
	@echo "                   │  https://github.com/epfl-si/wp-dev   │"
	@echo "                   └──────────────────────────────────────┘"
	@echo "                                           「EPFL ISAS-FSD」"

# The '##@' marker creates sections in the help message, and '##' at the end
# of the name of a rule (after its dependencies, if any) documents it.
	@awk 'BEGIN {FS = ":.*##"; printf "\n\033[1mUsage\033[0m\n"} /^[a-zA-Z_0-9-]+:.*?##/ { printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)

.PHONY: all
all: checkout git-pull up

WP_MAJOR_VERSION = 6
WP_SRC_DIR = src
WP_PHP_IMAGE_URL = quay-its.epfl.ch/svc0041/wp-php:2025-033

_docker_exec_clinic := docker exec --user www-data -it wp-clinic

############################# Pulling code #####################################
#
# As a matter of taste, we'd rather have Makefile-driven `git clone`s
# than submodules - Plus this lets you substitute your own arrangement
# if you wish.
#
# Code doesn't only get pulled from Git either: src is extracted
# from the "wp-base" Docker image.

.PHONY: checkout
checkout: ## Checkout wp-ops, wp-operator, menu-api, WP Themes and WP Plugins
	$(MAKE) .checkout

.checkout: \
  $(WP_SRC_DIR) \
  wp-ops \
  wp-operator \
  menu-api

$(WP_SRC_DIR):
	# TODO ensure wp-php
	-rm -f $(WP_SRC_DIR)
	mkdir -p "$@" || true
	chmod 1777 "$@" || true
	# Scratch haz nothing :( need bash or something. FIXME: Use wp-base instead of wp-php
	docker run -d --name wp-php-4-wp-extractor --rm $(WP_PHP_IMAGE_URL) sleep 100
	# Copy the latest version of WordPress from the image
	docker cp wp-php-4-wp-extractor:/wp/$(WP_MAJOR_VERSION)/. $(WP_SRC_DIR)
	touch $@

_find_git_depots := find . \( -path ./volumes -prune -false \) -o -name .git -prune |xargs -n 1 dirname|grep -v 'ansible-deps-cache'
.PHONY: git-status
git-status: ## Echo the `git status` of subdirectories
	@set -e; for dir in `$(_find_git_depots)`; do (cd $$dir; echo "$$(tput bold)$$dir$$(tput sgr0)"; git status -uno; echo); done

.PHONY: git-pull
git-pull: ## Walk down the directory to find repositories to update (with rebase!)
	@set -e; for dir in `$(_find_git_depots)`; do (cd $$dir; echo "$$(tput bold)$$dir$$(tput sgr0)"; git pull --rebase --autostash; echo); done


########################### Clone sub-repositories #############################
_git_clone = mkdir -p $@ || true; devscripts/ensure-git-clone.sh $(_GITHUB_BASE)$(strip $(1)) $@ $(2); touch $@

.PHONY: wp-ops
wp-ops:
	$(call _git_clone, epfl-si/wp-ops, WPN)

.PHONY: wp-operator
wp-operator:
	$(call _git_clone, epfl-si/wp-operator)

.PHONY: menu-api
menu-api:
	$(call _git_clone, epfl-si/wp-menu-api, WPN)


################################################################################
##@ Setup (Building or pulling Docker images)

ensure_wp_base := docker inspect wp-base >/dev/null 2>&1 || $(MAKE) wp-base

.PHONY: wp-base
wp-base: ## Build the WordPress base image, which several other images depend on
	docker build -t wp-base \
	--build-arg AWS_ACCESS_KEY_ID=$(AWS_ACCESS_KEY_ID) \
	--build-arg AWS_SECRET_ACCESS_KEY=$(AWS_SECRET_ACCESS_KEY) \
	wp-ops/docker/wp-base

.PHONY: docker-build
docker-build: ## Build the Docker images locally
	@$(ensure_wp_base)
	docker compose build $(DOCKER_BUILD_ARGS)

define expand_ver
case "$(VER)" in \
  202[456789]-*) ver="$(VER)" ;; \
  *) ver="$$(date +%Y)-$(VER)" ;; \
esac
endef

.PHONY: wpn
wpn: ## Build the wordpress-nginx and wordpress-php images
ifeq ($(VER),)
	$(error Need a value for VER, e.g., make wpn VER=001)
endif
	@$(ensure_wp_base)

	@$(expand_ver); \
	echo "Building wp-nginx:$$ver & wp-php:$$ver" ; \
	set -e -x; \
	docker build -t quay-its.epfl.ch/svc0041/wp-nginx:$$ver \
		wp-ops/docker/wordpress-nginx ; \
	docker build -t quay-its.epfl.ch/svc0041/wp-php:$$ver \
		wp-ops/docker/wordpress-php

.PHONY: wpn-push
wpn-push: ## Push the wordpress-nginx and wordpress-php images
	@$(expand_ver); \
	echo "Pushing wp-nginx:$$ver & wp-php:$$ver" ; \
	set -e -x; \
	docker push quay-its.epfl.ch/svc0041/wp-nginx:$$ver ; \
	docker push quay-its.epfl.ch/svc0041/wp-php:$$ver ; \
	echo "Now's probably a good time to run ./ansible/wpsible -t wp.web"


########################################################################
##@ Development Lifecycle

SITE_DIR := /srv/test/wp-httpd/htdocs

.PHONY: up
up: checkout run/nginx/nginx.conf var/wp-data run/nginx-entrypoint/nginx-entrypoint.php run/wp-nonces/wp-nonces.php run/certs src ## Start up a local WordPress instance
	docker compose up -d
	./devscripts/await-mariadb-ready
	# $(MAKE) rootsite
	@echo "If you have want to use the wp-gutenberg-epfl plugin or to dev on Gutenberg,"
	@echo "install nvm and run 'make gutenberg'"

run/nginx/nginx.conf: nginx-dev.conf
	# FIXME nginx configuration should be generated. Alors we need a way to
	# generate a couple of websites in it.
	mkdir -p run/nginx || true
	chmod 1777 run/nginx || true
	cp $< $@

run/nginx-entrypoint/nginx-entrypoint.php:
	# Scratch haz nothing :( need bash or something. FIXME: Use wp-base instead of wp-php
	@docker rm -f wp-php-4-wp-extractor 2>/dev/null || true
	docker run -d --name wp-php-4-wp-extractor --rm $(WP_PHP_IMAGE_URL) sleep 100
	# Copy the latest version of WordPress from the image
	docker cp wp-php-4-wp-extractor:/wp/nginx-entrypoint/ $$(dirname $@)

run/wp-nonces/wp-nonces.php:
	mkdir -p run/wp-nonces || true
	chmod 1777 run/wp-nonces || true
	echo "<?php" > run/wp-nonces/wp-nonces.php
	echo "// Generated from https://api.wordpress.org/secret-key/1.1/salt/" >> run/wp-nonces/wp-nonces.php
	curl -s https://api.wordpress.org/secret-key/1.1/salt/ >> run/wp-nonces/wp-nonces.php

# https://stackoverflow.com/a/41366949/960623
run/certs:
	mkdir -p $@ || true
	chmod 1777 $@ || true
	openssl req -x509 -newkey rsa:4096 -sha256 -days 3650 -nodes \
	  -keyout run/certs/wordpress.localhost.key \
	  -out run/certs/wordpress.localhost.crt \
	  -subj "/CN=wordpress.localhost"
	  # -addext "subjectAltName=DNS:wordpress.localhost,DNS:*.example.com,IP:10.0.0.1"
	chmod 666 run/certs/wordpress.localhost*

var/wp-data:
	mkdir -p $@ || true
	chmod 1777 $@ || true

# .PHONY: rootsite
# rootsite:
# 	@$(_docker_exec_clinic) bash -c 'wp --path=$(SITE_DIR) eval "1;"' ||    \
# 	  $(_docker_exec_clinic) bash -c '                                      \
# 	    set -e -x;                                                          \
# 	    mkdir -p $(SITE_DIR) || true;                                       \
# 	    cd $(SITE_DIR);                                                     \
# 	    export WORDPRESS_VERSION=$(WP_MAJOR_VERSION); new-wp-site --debug;  \
# 	    for subdir in plugins mu-plugins; do                                \
# 	      if [ ! -e wp-content/$$subdir ]; then                             \
# 	        ln -sfn ../wp/wp-content/$$subdir wp-content/$$subdir;          \
# 	      fi;                                                               \
# 	    done;                                                               \
# 	    mkdir -p $(SITE_DIR)/wp-content/themes;                             \
# 	    for subtheme in wp-theme-2018 wp-theme-light; do                    \
# 	      if [ ! -e wp-content/themes/$$subtheme ]; then                    \
# 	        ln -sfn ../../wp/wp-content/themes/wp-theme-2018.git/$$subtheme \
# 	        wp-content/themes/$$subtheme;                                   \
# 	      fi;                                                               \
# 	    done;                                                               \
# 	    wp theme activate wp-theme-2018;                                    \
# 	    wp user update admin --user_pass=secret;                            \
# 	    '

.PHONY: stop
stop: ## Stop the local WordPress instance
	docker compose stop

.PHONY: down
down: ## Stop the local WordPress instance and delete its containers
	docker compose down

nvm:
	. ${NVM_DIR}/nvm.sh && nvm install 20;

.PHONY: gutenberg
gutenberg: ## Start the development server for Gutenberg
	$(MAKE) nvm
	cd $(WP_SRC_DIR)/plugins/wp-gutenberg-epfl; npm install --silent --no-fund; npm start


########################################################################
##@ Daily Business

.PHONY: exec
exec: ## Enter the management container
	@$(_docker_exec_clinic) bash -l

.PHONY: nginx
nginx: ## Enter the nginx container
	@docker exec -it wp-nginx bash -l

.PHONY: php
php: ## Enter the PHP container
	@docker exec -it wp-php bash -l

.PHONY: mariadb
mariadb: ## Run a MariaDB command-line client
	@$(_docker_exec_clinic) bash -c 'mariadb -p$$MARIADB_ROOT_PASSWORD -u root -h mariadb'

.PHONY: wp-menu-api
wp-menu-api: ## Enter the menu-api container
	@docker exec -it wp-menu-api bash -l


########################################################################
##@ Backup / Restore

.PHONY: backup
backup: ## Backup the current state
	./devscripts/backup-restore backup wordpress-state.tgz

.PHONY: restore
restore: ## Restore the current state
	./devscripts/backup-restore restore wordpress-state.tgz


########################################################################
##@ Observe

.PHONY: logs
logs: ## Follow the docker compose's log
	docker compose logs -f --tail=5

.PHONY: tail-errors
tail-errors: ## Follow the nginx error log
	docker compose logs -f --tail=5 nginx

.PHONY: lnav
lnav:
	@$(_docker_exec_clinic) bash -c 'lnav /srv/*/logs'

.PHONY: tail-sql
tail-sql: ## Activate and follow the MariaDB general query log
	./devscripts/mysql-general-log tail


########################################################################
##@ Developer Support

CTAGS_FLAGS = --exclude=node_modules $(EXTRA_CTAGS_FLAGS) -R $(CTAGS_TARGETS)

CTAGS_TARGETS = $(WP_SRC_DIR)/*.php \
  $(WP_SRC_DIR)/wp-admin \
  $(WP_SRC_DIR)/wp-includes \
  $(WP_SRC_DIR)/themes/wp-theme-2018 \
  $(WP_SRC_DIR)/plugins/epfl-* \
  $(WP_SRC_DIR)/plugins/polylang \
  $(WP_SRC_DIR)/mu-plugins

tags: checkout ## Index the source code in vim format
	ctags $(CTAGS_FLAGS)

TAGS: checkout ## Index the source code in Emacs ”etags” format
	ctags -e $(CTAGS_FLAGS)


########################################################################
##@ Cleanup

.PHONY: clean-images
clean-images: ## Prune the Docker images
	docker_pulled_images="$$(cat docker-compose.yml | grep 'image: ' | grep -v default.svc | cut -d: -f2-)"; \
	docker_built_images="wp-base $$(shell cat docker-compose.yml | grep 'image: ' | grep default.svc | cut -d: -f2-)"; \
	for image in $$docker_pulled_images $$docker_built_images ; do docker rmi $$image || true; done
	docker image prune

.PHONY: clean
clean: down clean-images ## Tear down generated files and Docker-side state
	rm -f .make.vars TAGS tags

.PHONY: mrproper
mrproper: down ## Mr. Clean will clean your whole house and everything that's in it!
	@echo "Do you want to proceed with the action? This will remove everything. [y/n]: "
	@read answer; \
	if [ "$$answer" = "y" ] || [ "$$answer" = "Y" ]; then \
		echo "Whiping everything..."; \
		OS=$$(uname -s); \
		if [ "$$OS" = "Linux" ]; then \
			echo "This is a Linux system"; \
			sudo rm -rf $(WP_SRC_DIR) run var; \
		elif [ "$$OS" = "Darwin" ]; then \
			echo "This is a macOS system"; \
			rm -rf $(WP_SRC_DIR) run var; \
		else \
			echo "This OS is not supported"; \
		fi \
	else \
		echo "Action canceled."; \
	fi
