#!make

.PHONY: all
all: check-env checkout

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

.PHONY: check-env
check-env:
ifeq ($(wildcard .env),)
	@echo "Please create your .env file first, from env.sample"
	@exit 1
else
include .env
endif

_mgmt_container = $(shell docker ps -q --filter "label=ch.epfl.wordpress.mgmt.env=${WP_ENV}")
_httpd_container = $(shell docker ps -q --filter "label=ch.epfl.wordpress.httpd.env=${WP_ENV}")

.PHONY: vars
vars: check-env
	@echo 'Environment-related vars:'
	@echo '  WP_ENV=${WP_ENV}'
	@echo '  _mgmt_container=${_mgmt_container}'
	@echo '  _httpd_container=${_httpd_container}'

	@echo ''
	@echo DB-related vars:
	@echo '  MYSQL_ROOT_PASSWORD=${MYSQL_ROOT_PASSWORD}'
	@echo '  MYSQL_DB_HOST=${MYSQL_DB_HOST}'
	@echo '  MYSQL_SUPER_USER=${MYSQL_SUPER_USER}'
	@echo '  MYSQL_SUPER_PASSWORD=${MYSQL_SUPER_PASSWORD}'

	@echo ''
	@echo 'Wordpress-related vars:'
	@echo '  WP_VERSION=${WP_VERSION}'
	@echo '  WP_ADMIN_USER=${WP_ADMIN_USER}'
	@echo '  WP_ADMIN_EMAIL=${WP_ADMIN_EMAIL}'
	@echo '  WP_PORT_HTTP=${WP_PORT_HTTP}'
	@echo '  WP_PORT_HTTPS=${WP_PORT_HTTPS}'

	@echo ''
	@echo 'WPManagement-related vars:'
	@echo '  WP_PORT_PHPMA=${WP_PORT_PHPMA}'
	@echo '  WP_PORT_SSHD=${WP_PORT_SSHD}'
	@echo '  PLUGINS_CONFIG_BASE_PATH=${PLUGINS_CONFIG_BASE_PATH}'

######################## Pulling code ##########################
#
# As a matter of taste, we'd rather have Makefile-driven `git clone`s
# than submodules - Plus this lets you substitute your own arrangement

.PHONY: checkout
checkout: volumes/wp-content/themes/wp-theme-2018 \
  volumes/wp-content/plugins \
  volumes/wp-content/mu-plugins \
  wp-ops

# Figure out whether we clone over https or git+ssh (you need a GitHub
# account set up with an ssh public key for the latter)
_GITHUB_BASE := $(if $(shell ssh -T git@github.com 2>&1|grep 'successful'),git@github.com:,https://github.com/)

define git_clone =
@mkdir -p $(dir $@) || true
cd $(dir $@); git clone $(_GITHUB_BASE)$(strip $(1))
endef

wp-ops:
	$(call git_clone, epfl-idevelop/wp-ops)

volumes/wp-content/themes/wp-theme-2018:
	$(call git_clone, epfl-idevelop/wp-theme-2018)

# For historical reasons, plugins and mu-plugins currently
# reside in a repository called jahia2wp
volumes/wp-content/jahia2wp:
	$(call git_clone, epfl-idevelop/jahia2wp)

volumes/wp-content/plugins volumes/wp-content/mu-plugins: volumes/wp-content/jahia2wp
	@mkdir -p $(dir $@) || true
	ln -s jahia2wp/data/wp/wp-content/$(notdir $@) $@


.PHONY: pull
pull: check-env
	docker-compose pull

######################## Containers Lifecycle ##########################

.PHONY: up
up: check-env checkout
	docker-compose -p $(DOCKER_COMPOSE_PROJECT_NAME) up -d

.PHONY: down
down: check-env
	docker-compose -p $(DOCKER_COMPOSE_PROJECT_NAME) down


######################## Development Tasks ########################

.PHONY: exec
exec: check-env
	@docker exec --user www-data -it  \
	  -e WP_ENV=${WP_ENV} \
	  -e MYSQL_ROOT_PASSWORD=${MYSQL_ROOT_PASSWORD} \
	  -e MYSQL_DB_HOST=${MYSQL_DB_HOST} \
	  $(_mgmt_container) bash -l

.PHONY: httpd
httpd: check-env
	@docker exec -it $(_httpd_container) bash -l

######################## Cleaning up ##########################

.PHONY: clean
clean: down

