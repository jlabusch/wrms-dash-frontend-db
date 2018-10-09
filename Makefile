.PHONY: build network start stop clean

DOCKER=docker
NAME=wrms-dash-frontend-db
CONFIG_VOL=wrms-dash-config-vol
DB_VOL=wrms-dash-db-vol
NETWORK=wrms-dash-net

build:
	# create volumes if they don't exist
	$(DOCKER) volume ls | grep -q $(DB_VOL) || $(DOCKER) volume create $(DB_VOL)
	$(DOCKER) volume ls | grep -q $(CONFIG_VOL) || $(DOCKER) volume create $(CONFIG_VOL)
	# if needed, add a new random DB password to the config volume...
	$(DOCKER) images | grep -q alpine || $(DOCKER) pull alpine
	openssl rand -base64 32 | tr '/' '#' > pgpass && \
	CONTAINER=$$($(DOCKER) run -d -t -e TERM=xterm --rm -v $(CONFIG_VOL):/opt/ alpine top) && \
	( $(DOCKER) exec -it $$CONTAINER ls /opt/pgpass || $(DOCKER) cp ./pgpass $$CONTAINER:/opt/ ) && \
	$(DOCKER) stop $$CONTAINER || :
	@rm -f pgpass

network:
	$(DOCKER) network list | grep -q $(NETWORK) || $(DOCKER) network create $(NETWORK)

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

