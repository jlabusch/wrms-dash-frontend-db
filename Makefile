.PHONY: deps build network start stop clean

DOCKER=docker
NAME=wrms-dash-frontend-db
CONFIG_VOL=wrms-dash-config-vol
DB_VOL=wrms-dash-db-vol
NETWORK=wrms-dash-net
BUILD=$(shell ls ./wrms-dash-build-funcs/build.sh 2>/dev/null || ls ../wrms-dash-build-funcs/build.sh 2>/dev/null)
SHELL:=/bin/bash

deps:
	@test -n "$(BUILD)" || (echo 'wrms-dash-build-funcs not found; do you need "git submodule update --init"?'; false)
	@echo "Using $(BUILD)"

build: deps
	$(BUILD) image pull-if-not-exists alpine
	$(BUILD) volume create $(DB_VOL)
	$(BUILD) volume create $(CONFIG_VOL)
	@mkdir -p secret
	@$(BUILD) cp alpine $(CONFIG_VOL) $$PWD/secret /vol0/pgpass /vol1/ || :
	@test -f ./secret/pgpass || \
    openssl rand -base64 32 | tr '/' '#' > ./secret/pgpass && \
	$(BUILD) cp alpine $$PWD/secret/ $(CONFIG_VOL) /vol0/pgpass /vol1/
	@rm -fr secret

network:
	$(BUILD) network create $(NETWORK)

# This is the only component allowed to use volumes, because it isn't
# deployed on ECS in prod. (We just use RDS.)
start: network
	$(DOCKER) run \
        --name $(NAME) \
        --detach  \
        --expose 5432 \
        --env POSTGRES_USER=dashboard \
        --env POSTGRES_PASSWORD_FILE=/secrets/pgpass \
        --env POSTGRES_DB=dashboard \
        --env PGDATA=/var/lib/postgresql/data/pgdata \
        --volume $(DB_VOL):/var/lib/postgresql/data/pgdata \
        --volume $(CONFIG_VOL):/secrets:ro \
        --network $(NETWORK) \
        --rm \
        postgres:9.6
	$(DOCKER) logs -f $(NAME) &

stop:
	$(DOCKER) stop $(NAME)

clean:
	@echo "If you really want to do this, run \"$(DOCKER) volume rm $(DB_VOL)\""

