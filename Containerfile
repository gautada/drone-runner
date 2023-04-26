ARG ALPINE_VERSION=latest

# ╭―――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――╮
# │                                                                           │
# │ STAG1:BUILD                                                              │
# │                                                                           │
# ╰―――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――╯
FROM gautada/alpine:$ALPINE_VERSION as src

# ╭――――――――――――――――――――╮
# │ VERSION(S)         │
# ╰――――――――――――――――――――╯
ARG DRONE_RUNNER_EXEC_VERSION=1.0.0-beta.10
ARG DRONE_RUNNER_EXEC_BRANCH=v"$DRONE_RUNNER_EXEC_VERSION"

ARG DRONE_CLI_VERSION=1.6.2
ARG DRONE_CLI_BRANCH=v"$DRONE_CLI_VERSION"

# ╭――――――――――――――――――――╮
# │ PACKAGES           │
# ╰――――――――――――――――――――╯
RUN apk add --no-cache build-base git go
RUN git config --global advice.detachedHead false

# ╭――――――――――――――――――――╮
# │ SOURCE             │
# ╰――――――――――――――――――――╯
RUN mkdir -p /usr/lib/go/src/github.com
WORKDIR /usr/lib/go/src/github.com
RUN git clone --branch $DRONE_RUNNER_EXEC_BRANCH --depth 1 https://github.com/drone-runners/drone-runner-exec.git

RUN git clone --branch $DRONE_CLI_BRANCH --depth 1 https://github.com/harness/drone-cli.git

# ╭――――――――――――――――――――╮
# │ BUILD              │
# ╰―――――――――――――――――――╯
WORKDIR /usr/lib/go/src/github.com/drone-runner-exec
RUN go build -o release/linux/arm64/drone-runner-exec

 WORKDIR /usr/lib/go/src/github.com/drone-cli
# RUN go build -o release/linux/arm64/drone-cli
# Not sure why CLI is different thant the others
RUN go install ./...

# ╭――――――――――――――――-------------------------------------------------------――╮
# │                                                                         │
# │ STAGE: container                                                        │
# │                                                                         │
# ╰―――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――╯
FROM gautada/alpine:$ALPINE_VERSION

# ╭――――――――――――――――――――╮
# │ METADATA           │
# ╰――――――――――――――――――――╯
LABEL source="https://github.com/gautada/podman-container.git"
LABEL maintainer="Adam Gautier <adam@gautier.org>"
LABEL description="This container is a drone runner instance with git, podman, kubectl."

# ╭――――――――――――――――――――╮
# │ STANDARD CONFIG    │
# ╰――――――――――――――――――――╯

# USER:
ARG USER=runner

ARG UID=1001
ARG GID=1001
RUN /usr/sbin/addgroup -g $GID $USER \
 && /usr/sbin/adduser -D -G $USER -s /bin/ash -u $UID $USER \
 && /usr/sbin/usermod -aG wheel $USER \
 && /bin/echo "$USER:$USER" | chpasswd

# PRIVILEGE:
COPY wheel  /etc/container/wheel
RUN /bin/ln -fsv /etc/container/wheel /etc/sudoers.d/wheel

# BACKUP:
# COPY backup /etc/container/backup

# ENTRYPOINT:
RUN rm -v /etc/container/entrypoint
COPY entrypoint /etc/container/entrypoint

# FOLDERS
RUN /bin/chown -R $USER:$USER /mnt/volumes/container \
 && /bin/chown -R $USER:$USER /mnt/volumes/backup \
 && /bin/chown -R $USER:$USER /var/backup \
 && /bin/chown -R $USER:$USER /tmp/backup

# ╭――――――――――――――――――――╮
# │ APPLICATION        │
# ╰――――――――――――――――――――
RUN /sbin/apk add --no-cache git
RUN /sbin/apk add --no-cache buildah fuse-overlayfs podman py3-pip
# [Issue: Drop WETTY interface in favor of Bastion](https://github.com/gautada/drone-runner-container/issues/29)
# RUN /sbin/apk add --no-cache build-base yarn npm git openssh-client openssh
RUN /sbin/apk add --no-cache --repository http://dl-cdn.alpinelinux.org/alpine/edge/testing kubectl

RUN /usr/sbin/usermod --add-subuids 100000-165535 $USER \
 && /usr/sbin/usermod --add-subgids 100000-165535 $USER
 
COPY clean-runner /usr/bin/clean-runner

COPY --from=src /usr/lib/go/src/github.com/drone-runner-exec/release/linux/arm64/drone-runner-exec /usr/bin/drone-runner-exec

COPY --from=src /usr/lib/go/bin/drone /usr/bin/drone

RUN /bin/ln -fsv /mnt/volumes/configmaps/drone-runner-exec.env /etc/container/drone-runner-exec.env \
 && /bin/ln -fsv /mnt/volumes/container/drone-runner-exec.env /mnt/volumes/configmaps/drone-runner-exec.env

RUN /bin/ln -fsv /mnt/volumes/configmaps/drone-cli.env /etc/container/drone-cli.env \
 && /bin/ln -fsv /mnt/volumes/container/drone-cli.env /mnt/volumes/configmaps/drone-cli.env
 
RUN /bin/ln -fsv /mnt/volumes/configmaps/kubectl.cfg /etc/container/kubectl.cfg \
 && /bin/ln -fsv /mnt/volumes/container/kubectl.cfg /mnt/volumes/configmaps/kubectl.cfg \
 && /bin/mkdir -p /home/$USER/.kube \
 && /bin/ln -fsv /etc/container/kubectl.cfg /home/$USER/.kube/config
 
 RUN /bin/mkdir -p /home/$USER/.config/ca \
 && /bin/mkdir -p /home/$USER/.config/git

RUN /bin/ln -fsv /etc/container/gitconfig /etc/gitconfig \
 && /bin/ln -fsv /mnt/volumes/configmaps/gitconfig /etc/container/gitconfig \
 && /bin/ln -fsv /mnt/volumes/container/gitconfig /mnt/volumes/configmaps/gitconfig

RUN /bin/ln -fsv /mnt/volumes/secrets/git-credentials /etc/container/git-credentials \
 && /bin/ln -fsv /mnt/volumes/container/git-credentials /mnt/volumes/secrets/git-credentials

RUN /bin/ln -fsv /mnt/volumes/secrets/client-auth.crt /etc/container/client-auth.crt \
 && /bin/ln -fsv /mnt/volumes/container/client-auth.crt /mnt/volumes/secrets/client-auth.crt 

RUN /bin/ln -fsv /mnt/volumes/secrets/client-auth.key /etc/container/client-auth.key \
 && /bin/ln -fsv /mnt/volumes/container/client-auth.key /mnt/volumes/secrets/client-auth.key

RUN /usr/bin/pip3 install podman-compose

RUN mkdir -p /Volumes/container
RUN mkdir -p /Volumes/backup
RUN chown $USER:$USER /Volumes/*

# COPY drone-exports.sh /etc/profile.d/drone-exports.sh
COPY compose-service /usr/bin/compose-service

# ╭――――――――――――――――――――╮
# │ CONTAINER          │
# ╰――――――――――――――――――――╯
RUN /bin/chown -R $USER:$USER /home/$USER
USER $USER
VOLUME /mnt/volumes/backup
VOLUME /mnt/volumes/configmaps
VOLUME /mnt/volumes/container
# # [Issue: Drop WETTY interface in favor of Bastion](https://github.com/gautada/drone-runner-container/issues/29)
# EXPOSE 8080/tcp
EXPOSE 3000/tcp
WORKDIR /home/$USER

# ╭――――――――――――――――――――╮
# │ CONFIGRE          │
# ╰――――――――――――――――――――╯
# [Issue: Drop WETTY interface in favor of Bastion](https://github.com/gautada/drone-runner-container/issues/29)
# RUN /usr/bin/yarn global add wetty
# Setup UNIX sockert support for podman.
RUN /bin/mkdir -p /tmp/podman-run-1001/podman
RUN /usr/bin/podman system connection add sock unix:///tmp/podman-run-1001/podman/podman.sock
RUN /usr/bin/podman system connection default sock


