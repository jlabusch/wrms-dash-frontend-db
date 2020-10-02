.PHONY: deps build network start stop clean

DOCKER=docker
NAME=wrms-dash-frontend-db
DB_VOL=wrms-dash-db-vol
NETWORK=wrms-dash-net
BUILD=$(shell ls ./wrms-dash-build-funcs/build.sh 2>/dev/null || ls ../wrms-dash-build-funcs/build.sh 2>/dev/null)
SHELL:=/bin/bash

deps:
	@test -n "$(BUILD)" || (echo 'wrms-dash-build-funcs not found; do you need "git submodule update --init"?'; false)
	@echo "Using $(BUILD)"

pgpass:
	@openssl rand -base64 32 | tr '/' '#' > ./pgpass

build: deps pgpass
	@:

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
        --env POSTGRES_PASSWORD=$$(cat ./pgpass) \
        --env POSTGRES_DB=dashboard \
        --env PGDATA=/var/lib/postgresql/data/pgdata \
        --volume $(DB_VOL):/var/lib/postgresql/data/pgdata \
        --network $(NETWORK) \
        --rm \
        postgres:12.4
	$(DOCKER) logs -f $(NAME) &

stop:
	$(DOCKER) stop $(NAME)

clean:
	@echo "If you really want to do this, run \"$(DOCKER) volume rm $(DB_VOL)\" and \"rm ./pgpass\""

