FROM ubuntu:jammy

LABEL Description="Dockerized Python/MiKTeX, Ubuntu 22.04LTS" Vendor="IVER" Version="1.0"
LABEL org.opencontainers.image.description="Dockerized Python/MiKTeX, Ubuntu 22.04LTS"

ARG DEBIAN_FRONTEND=noninteractive

# http://bugs.python.org/issue19846
# > At the moment, setting "LANG=C" on a Linux system *fundamentally breaks Python 3*, and that's not OK.
ENV LANG C.UTF-8
# Miktex setup vars
ENV MIKTEX_USERCONFIG=/miktex/.miktex/texmfs/config
ENV MIKTEX_USERDATA=/miktex/.miktex/texmfs/data
ENV MIKTEX_USERINSTALL=/miktex/.miktex/texmfs/install

# Install OS extras
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        apt-transport-https \
        ca-certificates \
        curl \
        software-properties-common \
        dirmngr \
        ghostscript \
        gnupg \
        gosu \
        make \
        perl

## Setup non root user
ARG USERNAME=user
ARG USER_UID=1000
ARG USER_GID=$USER_UID
# Create the user
RUN groupadd --gid $USER_GID $USERNAME \
    && useradd --uid $USER_UID --gid $USER_GID -m $USERNAME --create-home
RUN mkdir /app && chown -R $USERNAME:$USERNAME /app
WORKDIR /app

### Add python to image
RUN add-apt-repository ppa:deadsnakes/ppa \
    && apt-get install -y --no-install-recommends \
        python3.11 \
        python3.11-venv \
    && update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.11 100 \
    && apt-get install -y --no-install-recommends \
        python-is-python3
RUN curl https://bootstrap.pypa.io/get-pip.py > /home/$USERNAME/get-pip.py \
    && chmod +x /home/$USERNAME/get-pip.py
## Enable pip binaries from user path.
ENV PATH /home/$USERNAME/.local/bin:$PATH
# Ensure local python is preferred over distribution python
ENV PATH /usr/local/bin:$PATH

# Install Miktex
RUN gpg -k  \
    && gpg --no-default-keyring --keyring /usr/share/keyrings/miktex.gpg \
    --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys D6BC243565B2087BC3F897C9277A7293F59E4889
RUN echo "deb  [signed-by=/usr/share/keyrings/miktex.gpg] https://miktex.org/download/ubuntu jammy universe" | tee /etc/apt/sources.list.d/miktex.list
RUN apt-get update -y \
    && apt-get install -y --no-install-recommends \
        miktex

## Setup miktex
RUN mkdir /miktex \
    && miktexsetup --shared=yes finish \
    && initexmf --admin --set-config-value=[MPM]AutoInstall=1 \
    && miktex --admin packages update-package-database \
    && miktex --admin packages update \
    && miktex --admin fndb refresh
RUN chown -R $USERNAME:$USERNAME /miktex

COPY --chown=$USERNAME:$USERNAME entrypoint.sh /home/$USERNAME
RUN chown $USERNAME:$USERNAME /home/$USERNAME/entrypoint.sh
ENTRYPOINT $HOME/entrypoint.sh

# Set userlevel execution
RUN chown -R $USERNAME:$USERNAME /app
USER $USERNAME

## Get pip as user. Create a user level python virtual environemnt.
RUN python3 -m venv /app/docker_venv \
    && . /app/docker_venv/bin/activate \
    && python3 /home/$USERNAME/get-pip.py

