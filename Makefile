.PHONY: all
all: checkout up

include .env

-include .make.vars

# Auto-detected variables (computed once and stored until "make clean")
.make.vars: docker-compose.yml
# Figure out whether we clone over https or git+ssh (you need a GitHub
# account set up with an ssh public key for the latter)
	echo "# Auto-generated by Makefile, DO NOT EDIT" > $@
	echo _GITHUB_BASE = $(if $(shell ssh -T git@github.com 2>&1|grep 'successful'),git@github.com:,https://github.com/) >> $@
	echo _DOCKER_PULLED_IMAGES = $(shell cat docker-compose.yml | grep 'image: ' | grep -v epflidevelop | cut -d: -f2-) >> $@
	echo _DOCKER_BUILT_IMAGES = $(shell cat docker-compose.yml | grep 'image: ' | grep epflidevelop | cut -d: -f2-) >> $@

m = $(notdir $(MAKE))
.PHONY: help
help:
	@echo 'Usage:'
	@echo
	@echo '$(m) help           Show this message'
	@echo
	@echo '$(m) up             Start up a local WordPress instance'
	@echo '                    with docker-compose for development.'
	@echo '                    Be sure to review ../README.md for'
	@echo '                    preliminary steps (entry in /etc/hosts,'
	@echo '                    .env file and more)'
	@echo
	@echo '$(m) down           Bring down the development environment'
	@echo '$(m) clean'
	@echo
	@echo '$(m) exec           Enter the management container'
	@echo
	@echo '$(m) httpd          Enter the Apache container'
	@echo
	@echo "$(m) tail-access    Follow the tail of Apache's access resp."
	@echo '$(m) tail-errors    error logs through the terminal'
	@echo

# Default values, can be overridden either on the command line of make
# or in .env
WP_ENV ?= your-env
WP_PORT_HTTP ?= 80
WP_PORT_HTTPS ?= 443

DOCKER_COMPOSE_PROJECT_NAME = wp-local

DOCKER_IMAGE_STAMPS = .docker-images-pulled.stamp \
	.docker-base-images-built.stamp \
	.docker-local-images-built.stamp

DOCKER_BASE_IMAGE_NAME = epflidevelop/os-wp-base
DOCKER_HTTPD_IMAGE_NAME = epflidevelop/os-wp-httpd

WP_CONTENT_DIR = volumes/wp/wp-content
JAHIA2WP_TOPDIR = $(WP_CONTENT_DIR)/jahia2wp

_mgmt_container = $(shell docker ps -q --filter "label=ch.epfl.wordpress.mgmt.env=$(WP_ENV)")
_httpd_container = $(shell docker ps -q --filter "label=ch.epfl.wordpress.httpd.env=$(WP_ENV)")

.PHONY: vars
vars:
	@echo 'Environment-related vars:'
	@echo '  WP_ENV=$(WP_ENV)'
	@echo '  _mgmt_container=$(_mgmt_container)'
	@echo '  _httpd_container=$(_httpd_container)'

	@echo ''
	@echo DB-related vars:
	@echo '  MYSQL_ROOT_PASSWORD=$(MYSQL_ROOT_PASSWORD)'
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
# from the "httpd" Docker image, and we create a couple of symlinks too.

.PHONY: checkout
checkout: \
  volumes/wp \
  $(WP_CONTENT_DIR)/themes/wp-theme-2018 \
  $(WP_CONTENT_DIR)/plugins \
  $(WP_CONTENT_DIR)/mu-plugins \
  $(JAHIA2WP_TOPDIR) \
  wp-ops

git_clone = mkdir -p $(dir $@) || true; cd $(dir $@); test -d $(notdir $@) || git clone $(_GITHUB_BASE)$(strip $(1)) $(notdir $@); touch $(notdir $@)

volumes/wp: .docker-local-images-built.stamp
	docker run --rm  --name volumes-wp-extractor \
	  --entrypoint /bin/bash \
	  $(DOCKER_HTTPD_IMAGE_NAME) \
	  -c "tar --exclude=/wp/wp-content/{plugins,mu-plugins,themes} \
              -clf - /wp" \
	  | tar -Cvolumes -xpvf - wp
	touch $@

$(WP_CONTENT_DIR)/themes/wp-theme-2018: volumes/wp
	$(call git_clone, epfl-idevelop/wp-theme-2018)

$(WP_CONTENT_DIR)/plugins $(WP_CONTENT_DIR)/mu-plugins: $(JAHIA2WP_TOPDIR)
	@mkdir -p $(dir $@) || true
	ln -sf jahia2wp/data/wp/wp-content/$(notdir $@) $@

# For historical reasons, plugins and mu-plugins currently
# reside in a repository called jahia2wp
$(JAHIA2WP_TOPDIR): volumes/wp
	$(call git_clone, epfl-idevelop/jahia2wp)

wp-ops:
	$(call git_clone, epfl-idevelop/wp-ops)

################ Building or pulling Docker images ###############

.PHONY: pull
pull:
	rm -f .docker-images-pulled.stamp
	$(MAKE) .docker-images-pulled.stamp

.docker-images-pulled.stamp: docker-compose.yml
	for image in $(_DOCKER_PULLED_IMAGES); do docker pull $$image; done
	@mkdir -p $(dir $@)
	touch $@

.docker-base-images-built.stamp: wp-ops
	[ -d wp-ops/docker/wp-base ] && \
	  docker build -t $(DOCKER_BASE_IMAGE_NAME) wp-ops/docker/wp-base
	@mkdir -p $(dir $@)
	touch $@

.docker-local-images-built.stamp: .docker-base-images-built.stamp wp-ops
	docker-compose build
	@mkdir -p $(dir $@)
	touch $@

.PHONY: docker-build
docker-build:
	rm -f .docker*built.stamp
	$(MAKE) .docker-local-images-built.stamp

.PHONY: clean-images
clean-images:
	for image in $(_DOCKER_PULLED_IMAGES) $(_DOCKER_BUILT_IMAGES) epflidevelop/os-wp-base; do docker rmi $$image || true; done
	rm -f .docker*.stamp


######################## Containers Lifecycle #####################

.PHONY: up
up: checkout $(DOCKER_IMAGE_STAMPS)
	docker-compose -p $(DOCKER_COMPOSE_PROJECT_NAME) up -d

.PHONY: down
down:
	docker-compose -p $(DOCKER_COMPOSE_PROJECT_NAME) down


######################## Development Tasks ########################

.PHONY: exec
exec:
	@docker exec --user www-data -it  \
	  -e WP_ENV=$(WP_ENV) \
	  -e MYSQL_ROOT_PASSWORD=$(MYSQL_ROOT_PASSWORD) \
	  -e MYSQL_DB_HOST=$(MYSQL_DB_HOST) \
	  $(_mgmt_container) bash -l

.PHONY: httpd
httpd:
	@docker exec -it $(_httpd_container) bash -l

.PHONY: tail-errors
tail-errors:
	tail -F volumes/srv/*/logs/error_log.*.`date +%Y%m%d`

.PHONY: tail-access
tail-access:
	tail -F volumes/srv/*/logs/access_log.*.`date +%Y%m%d`


######################## Cleaning up ##########################

.PHONY: clean
clean: down clean-images
	rm .make.vars


