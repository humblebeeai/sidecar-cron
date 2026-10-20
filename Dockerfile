# syntax=docker/dockerfile:1
# check=skip=SecretsUsedInArgOrEnv

ARG PYTHON_VERSION=3.11
ARG BASE_IMAGE=python:${PYTHON_VERSION}-slim-trixie

ARG DEBIAN_FRONTEND=noninteractive


## Here is the builder image:
FROM ${BASE_IMAGE} AS builder

ARG DEBIAN_FRONTEND
ARG DOCKER_VERSION=29.7.2
ARG DOCKER_COMPOSE_VERSION=5.5.0

ENV	UV_LINK_MODE=copy

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

WORKDIR /usr/src/cron

RUN --mount=type=cache,target=/root/.cache,sharing=locked \
	_BUILD_TARGET_ARCH=$(uname -m) && \
	echo "BUILDING TARGET ARCHITECTURE: ${_BUILD_TARGET_ARCH}" && \
 	case "${_BUILD_TARGET_ARCH}" in \
 		x86_64|amd64) _DOCKER_ARCH="x86_64" ;; \
 		aarch64|arm64) _DOCKER_ARCH="aarch64" ;; \
 		*) echo "[ERROR]: Unsupported architecture: ${_BUILD_TARGET_ARCH}" >&2; exit 1 ;; \
 	esac && \
	rm -rfv /var/lib/apt/lists/* /var/cache/apt/archives/* /tmp/* && \
	apt-get clean -y && \
	apt-get update --fix-missing -o Acquire::CompressionTypes::Order::=gz && \
	apt-get install -y --no-install-recommends curl tar && \
	curl -SL -# https://download.docker.com/linux/static/stable/${_DOCKER_ARCH}/docker-${DOCKER_VERSION}.tgz -o docker.tgz && \
	tar -xzf docker.tgz && \
	curl -SL -# https://github.com/docker/compose/releases/download/v${DOCKER_COMPOSE_VERSION}/docker-compose-linux-${_DOCKER_ARCH} -o docker-compose && \
	python3 -m pip install --timeout 60 -U pip uv

# COPY ./requirements* ./
RUN	--mount=type=cache,target=/root/.cache,sharing=locked \
	--mount=type=bind,source=requirements.txt,target=requirements.txt \
	python3 -m uv pip install --prefix=/install -r ./requirements.txt

# Here is the production image
FROM ${BASE_IMAGE} AS base

ARG DEBIAN_FRONTEND

ARG UID=1000
ARG USER=cron-user
ARG GID=11000
ARG GROUP=cron-group
## echo "USER_PASSWORD123" | openssl passwd -6 -stdin
ARG HASH_PASSWORD="\$6\$tl0vbaVo9vXqW6d2$.YHPpjSMUaitcS6p0TmFdnr4ylXHefp5pLAc403PlkwulUekvxBld2cebLQAjzBgCEdweJjLOaYrYW/alB5Q7."

ENV UID=${UID} \
	USER=${USER} \
	GID=${GID} \
	GROUP=${GROUP} \
	PYTHONIOENCODING=utf-8 \
	PYTHONUNBUFFERED=1

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

RUN --mount=type=secret,id=HASH_PASSWORD \
	rm -vrf /var/lib/apt/lists/* /var/cache/apt/archives/* /tmp/* /root/.cache/* && \
	apt-get clean -y && \
	apt-get update --fix-missing -o Acquire::CompressionTypes::Order::=gz && \
	apt-get install -y --no-install-recommends \
		sudo \
		gosu \
		locales \
		tzdata \
		procps \
		iputils-ping \
		iproute2 \
		ca-certificates \
		curl \
		wget \
		jq \
		nano \
		tar \
		ssh \
		git \
		openssl \
		postgresql-client \
		tini \
		cron && \
	apt-get clean -y && \
	sed -i -e 's/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen && \
	sed -i -e 's/# en_AU.UTF-8 UTF-8/en_AU.UTF-8 UTF-8/' /etc/locale.gen && \
	sed -i -e 's/# ko_KR.UTF-8 UTF-8/ko_KR.UTF-8 UTF-8/' /etc/locale.gen && \
	dpkg-reconfigure --frontend=noninteractive locales && \
	update-locale LANG=en_US.UTF-8 && \
	echo "LANGUAGE=en_US.UTF-8" >> /etc/default/locale && \
	echo "LC_ALL=en_US.UTF-8" >> /etc/default/locale && \
	addgroup --gid ${GID} ${GROUP} && \
	useradd -lmN -d "/home/${USER}" -s /bin/bash -g ${GROUP} -G sudo -u ${UID} ${USER} && \
	if [ -f "/run/secrets/HASH_PASSWORD" ]; then \
		echo "Using hashed password from secret: /run/secrets/HASH_PASSWORD"; \
		echo -e "${USER}:$(cat /run/secrets/HASH_PASSWORD)" | chpasswd -e; \
	else \
		echo "Using hashed password from build argument: HASH_PASSWORD"; \
		echo -e "${USER}:${HASH_PASSWORD}" | chpasswd -e; \
	fi && \
	echo -e "\nalias ls='ls -aF --group-directories-first --color=auto'" >> /root/.bashrc && \
	echo -e "alias ll='ls -alhF --group-directories-first --color=auto'\n" >> /root/.bashrc && \
	echo -e "\numask 0002" >> "/home/${USER}/.bashrc" && \
	echo "alias ls='ls -aF --group-directories-first --color=auto'" >> "/home/${USER}/.bashrc" && \
	echo -e "alias ll='ls -alhF --group-directories-first --color=auto'\n" >> "/home/${USER}/.bashrc" && \
	pip install --timeout 60 --no-cache-dir --upgrade pip && \
	pip cache purge && \
	rm -rfv /var/lib/apt/lists/* /var/cache/apt/archives/* /tmp/* /root/.cache/* /home/${USER}/.cache/* && \
	mkdir -pv /app/cron/configs/cron.d \
		/app/cron/scripts/periodic/cron.hourly \
		/app/cron/scripts/periodic/cron.daily \
		/app/cron/scripts/periodic/cron.weekly \
		/app/cron/scripts/periodic/cron.monthly \
		/var/log/cron && \
	chown -Rc "${USER}:${GROUP}" /app/cron /var/log/cron && \
	find /app/cron -type d -exec chmod -c 770 {} + && \
	find /app/cron -type d -exec chmod -c ug+s {} + && \
	find /var/log/cron -type d -exec chmod -c 775 {} + && \
	find /var/log/cron -type d -exec chmod -c +s {} +

ENV	LANG=en_US.UTF-8 \
	LANGUAGE=en_US.UTF-8 \
	LC_ALL=en_US.UTF-8

COPY --from=builder --chown=${UID}:${GID} /install /usr/local
COPY --from=builder --chown=root:root --chmod=755 /usr/src/cron/docker/docker /usr/bin/docker
COPY --from=builder --chown=root:root --chmod=755 /usr/src/cron/docker-compose /usr/local/lib/docker/cli-plugins/docker-compose


## Here is the final image:
FROM base AS app

WORKDIR /app/cron
COPY --chown=${UID}:${GID} --chmod=770 ./src /app/cron
COPY --chown=root:root --chmod=775 ./scripts/docker/*.sh /usr/local/bin/

ENTRYPOINT ["docker-entrypoint.sh"]
