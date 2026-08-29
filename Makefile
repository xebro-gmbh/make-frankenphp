#--------------------------
# xebro GmbH - FrankenPHP - 1.0.0
#--------------------------

.PHONY: php.help php.logs worker.logs worker.restart php.bash php.cc php.db php.fixtures php.migrate php.migration \
        php.test php.coverage php.composer.prod php.composer.dev php.assets php.stan php.cpd php.pdepend \
        php.lint php.cs-fixer php.cs-check php.install php.docker.build php.restart \
        php.exec php.cmd php.validate_db php.jwt_keys php.post_start php.debug \
        ci debug fix help init install lint php.verify restart test post_start
XO_PHP_PORT ?= 80
XO_PHP_TLS_PORT ?= 443

DOCKER_PHP=${DOCKER_COMPOSE} run --rm php
SYMFONY_CONSOLE=${DOCKER_PHP} ./bin/console

PHP_DIR := $(patsubst $(XO_ROOT_DIR)/%,./%,$(dir $(abspath $(lastword $(MAKEFILE_LIST)))))
PHP_DIR_ABS := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))

PHP := $(notdir $(patsubst %/,%,$(PHP_DIR)))

php.help:
	$(call add_help,${PHP_DIR}Makefile,"PHP")

php.logs: ## Show docker logs
	@${DOCKER_COMPOSE} logs -f php

worker.logs: ## Show worker docker logs
	@${DOCKER_COMPOSE} logs -f php-worker

php.bash: ## Open bash inside the container
	@${DOCKER_PHP} bash

php.cc: ## Clear the symfony cache
	$(call target_name,$@)
	@${SYMFONY_CONSOLE} c:c

php.db: ## Update database schema
	$(call target_name,$@)
	@${SYMFONY_CONSOLE} doctrine:schema:update --force

php.fixtures: ## Install all fixtures
	$(call target_name,$@)
	@${SYMFONY_CONSOLE} doctrine:fixtures:load --purge-with-truncate -n

php.migrate: ## Apply all migrations
	$(call target_name,$@)
	@${SYMFONY_CONSOLE} doctrine:migrations:migrate -n

php.migration: ## Create migration
	$(call target_name,$@)
	$(MAKE) stop
	$(MAKE) start
	$(MAKE) php.migrate
	@${SYMFONY_CONSOLE} make:migration -n
	$(MAKE) php.migrate
	$(MAKE) php.fixtures


php.test: ## Run PHPUnit tests
	$(call target_name,$@)
	@${DOCKER_PHP} bash -c 'rm -rf var/cache/test; rm -f var/app_test.db var/app_test.db-*; if [ ! -f ./vendor/bin/phpunit ]; then echo "phpunit not found at ./vendor/bin/phpunit. Run composer install to install it."; exit 1; fi; ./vendor/bin/phpunit'

php.coverage: ## Run PHPUnit tests with code coverage, HTML report in api/var/coverage/
	$(call target_name,$@)
	@${DOCKER_PHP} bash -c 'if [ ! -f ./vendor/bin/phpunit ]; then echo "phpunit not found at ./vendor/bin/phpunit. Run composer install to install it."; exit 1; fi'
	@${DOCKER_PHP} bash -c "XDEBUG_MODE=coverage ./vendor/bin/phpunit --coverage-html=var/coverage/"
	@echo "Coverage report: file://${XO_ROOT_DIR}/${XO_PHP_ROOT}var/coverage/index.html"

php.composer.prod:
	@${DOCKER_PHP} composer install --no-ansi --no-dev --no-interaction --no-plugins --no-progress --no-scripts --optimize-autoloader

php.composer.dev:
	@${DOCKER_PHP} composer install --no-ansi --no-interaction --no-progress

php.assets: ## Install assets
	$(call target_name,$@)
	@${SYMFONY_CONSOLE} assets:install

php.stan: ## Analyse php code
	$(call target_name,$@)
	@${DOCKER_PHP} ./vendor/bin/phpstan analyze -c phpstan.dist.neon --memory-limit=512M

php.cpd: ## Find copy-paste duplicates
	$(call target_name,$@)
	@${DOCKER_PHP} ./vendor/bin/phpcpd src/ --min-lines 5

php.pdepend: ## Analyze code metrics and duplicates
	$(call target_name,$@)
	@${DOCKER_PHP} ./vendor/bin/pdepend --jdepend-chart=var/jdepend.svg --summary-xml=var/pdepend.xml --jdepend-chart=var/jdepend.svg src/

php.lint:  ## Lint code
	$(call target_name,$@)
	@${DOCKER_PHP} ./vendor/bin/phplint src/
	@${SYMFONY_CONSOLE} lint:container
	@${SYMFONY_CONSOLE} lint:yaml --parse-tags config/
	@${SYMFONY_CONSOLE} lint:twig templates

php.cs-fixer: ## Code style fix
	$(call target_name,$@)
	@${DOCKER_PHP} ./vendor/bin/php-cs-fixer fix

php.cs-check: ## Code style check
	$(call target_name,$@)
	@${DOCKER_PHP} ./vendor/bin/php-cs-fixer check

php.install:
	$(call headline,"Installing php")
	$(call seed_env_vars,".env","${PHP_DIR}config/.env.seed")
	$(call ensure_env_vars,".env","${PHP_DIR}config/.env")
	$(call ensure_lines,.gitignore,${PHP_DIR}config/.gitignore)
	@mkdir -p ${XO_CONFIG_DIR}/composer_tmp

php.docker.build: ## Build php container
	@${DOCKER_COMPOSE} build php

php.restart: php.migrate php.fixtures ## Restart PHP
	$(call target_name,$@)
	@${DOCKER_COMPOSE} restart php

worker.restart: ## Restart PHP worker
	$(call target_name,$@)
	@${DOCKER_COMPOSE} restart php-worker

php.exec:
	${DOCKER_PHP} bash -c $${cmd}

php.cmd:
	${SYMFONY_CONSOLE} $${cmd}

php.validate_db:
	$(call target_name,$@)
	@${SYMFONY_CONSOLE} doctrine:schema:validate

php.jwt_keys:
	@${SYMFONY_CONSOLE} lexik:jwt:generate-keypair --skip-if-exists

php.post_start:
	@$(call target_name,"PHP")
	@printf "${Purple}API URL: ${Yellow}http://localhost:${XO_PHP_PORT}\n"
	@printf "${Purple}API URL (TLS): ${Yellow}https://localhost:${XO_PHP_TLS_PORT}\n"
	@printf "${Purple}Src DIR: ${Yellow}${XO_PHP_ROOT}\n"

php.debug: ## Print PHP component environment
	@$(call target_name,"DEBUGGING PHP")
	@printf "${Purple}PHP: ${Yellow} ${PHP}\n"
	@printf "${Purple}PHP_DIR: ${Yellow} ${PHP_DIR}\n"

ci: php.cs-fixer php.stan php.lint php.validate_db php.test node.lint node.test
debug: php.debug
fix: php.cs-fixer php.stan
help: php.help
init: php.install php.docker.build php.composer.dev php.migrate php.fixtures php.cc
install: php.install
lint: php.lint php.validate_db
php.verify: php.cs-fixer php.stan php.lint php.validate_db php.test ## Run CS fix, static analysis, lint, DB validate, tests
restart: php.restart
test: php.test
post_start: php.post_start