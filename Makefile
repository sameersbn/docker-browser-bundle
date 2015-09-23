all: build

XSOCK=/tmp/.X11-unix
XAUTH=/tmp/.docker.xauth

CAPABILITIES = \
	--cap-add=SYS_ADMIN

ENV_VARS= \
	--env="USER_UID=$(shell id -u)" \
	--env="USER_GID=$(shell id -g)" \
	--env="DISPLAY" \
	--env="XAUTHORITY=${XAUTH}"

VOLUMES = \
	--volume=${XSOCK}:${XSOCK} \
	--volume=${XAUTH}:${XAUTH} \
	--volume=/run/user/$(shell id -u)/pulse:/run/pulse

help:
	@echo ""
	@echo "-- Help Menu"
	@echo ""
	@echo "   1. make build            - build the browser-box image"
	@echo "   1. make install          - install launch wrappers"
	@echo "   2. make google-chrome    - launch google-chrome"
	@echo "   2. make tor-browser      - launch tor-browser"
	@echo "   2. make bash             - bash login"
	@echo ""

clean:
	@docker rm -f `docker ps -a | grep "${USER}/browser-box" | awk '{print $$1}'` > /dev/null 2>&1 || exit 0
	@docker rmi `docker images  | grep "${USER}/browser-box" | awk '{print $$3}'` > /dev/null 2>&1 || exit 0


build: clean
	@docker build --rm=true --tag=${USER}/browser-box .

install uninstall: clean build
	@docker run -it --rm \
		--volume=/usr/local/bin:/target \
		${USER}/browser-box:latest $@

google-chrome tor-browser chromium-browser firefox bash:
	@touch ${XAUTH}
	@xauth nlist :0 | sed -e 's/^..../ffff/' | xauth -f ${XAUTH} nmerge -
	docker run -it --rm \
		${CAPABILITIES} \
		${ENV_VARS} \
		${VOLUMES} \
		${USER}/browser-box:latest $@
