ARG ALPINE_VERSION=latest

FROM docker.io/gautada/alpine:$ALPINE_VERSION as src

# ╭――――――――――――――――――――╮
# │ VERSION(S)         │
# ╰――――――――――――――――――――╯
ARG CONTAINER_VERSION="1.0.0"
ARG DRONE_RUNNER_KUBE_VERSION="$CONTAINER_VERSION"
ARG DRONE_RUNNER_KUBE_RELEASE="-rc.3"
ARG DRONE_RUNNER_KUBE_BRANCH=v"$DRONE_RUNNER_KUBE_VERSION""$DRONE_RUNNER_KUBE_RELEASE"

ARG DRONE_CLI_VERSION=1.6.2
ARG DRONE_CLI_BRANCH=v"$DRONE_CLI_VERSION"

RUN apk add --no-cache build-base git go

RUN git config --global advice.detachedHead false
RUN mkdir -p /usr/lib/go/src/github.com
WORKDIR /usr/lib/go/src/github.com

RUN echo "$DRONE_RUNNER_KUBE_BRANCH"
RUN git clone --branch "$DRONE_RUNNER_KUBE_BRANCH" --depth 1 https://github.com/drone-runners/drone-runner-kube.git
RUN git clone --branch $DRONE_CLI_BRANCH --depth 1 https://github.com/harness/drone-cli.git

WORKDIR /usr/lib/go/src/github.com/drone-runner-kube
RUN go build -o release/linux/arm64/drone-runner-kube
WORKDIR /usr/lib/go/src/github.com/drone-cli
# RUN go build -o release/linux/arm64/drone-cli
# Not sure why CLI is different thant the others
RUN go install ./...

# ╭――――――――――――――――-------------------------------------------------------――╮
# │                                                                         │
# │ STAGE: container                                                        │
# │                                                                         │
# ╰―――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――╯
FROM docker.io/gautada/alpine:$ALPINE_VERSION as container

# ╭――――――――――――――――――――╮
# │ METADATA           │
# ╰――――――――――――――――――――╯
LABEL source="https://github.com/gautada/drone-runner-container.git"
LABEL maintainer="Adam Gautier <adam@gautier.org>"
LABEL description="This container is a drone runner instance with git, podman, kubectl."

# ╭―
# │ USER
# ╰――――――――――――――――――――
ARG USER=runner
RUN /usr/sbin/usermod -l $USER alpine
RUN /usr/sbin/usermod -d /home/$USER -m $USER
RUN /usr/sbin/groupmod -n $USER alpine
RUN /bin/echo "$USER:$USER" | /usr/sbin/chpasswd

# ╭―
# │ PRIVILEGES
# ╰――――――――――――――――――――
COPY privileges /etc/container/privileges
# COPY wheel  /etc/container/wheel
# RUN /bin/ln -fsv /etc/container/wheel /etc/sudoers.d/wheel

# BACKUP:
RUN /bin/rm -f /etc/periodic/hourly/container-backup
# COPY backup /etc/container/backup

# ENTRYPOINT:
COPY entrypoint /etc/container/entrypoint


# ╭――――――――――――――――――――╮
# │ APPLICATION        │
# ╰――――――――――――――――――――
RUN /sbin/apk add --no-cache git
RUN /sbin/apk add --no-cache buildah fuse-overlayfs podman py3-pip
# [Issue: Drop WETTY interface in favor of Bastion](https://github.com/gautada/drone-runner-container/issues/29)
# RUN /sbin/apk add --no-cache build-base yarn npm git openssh-client openssh
RUN /sbin/apk add --no-cache --repository http://dl-cdn.alpinelinux.org/alpine/edge/testing kubectl

# RUN /usr/sbin/usermod --add-subuids 100000-165535 $USER \
#  && /usr/sbin/usermod --add-subgids 100000-165535 $USER

COPY --from=src /usr/lib/go/bin/drone /usr/bin/drone
COPY --from=src /usr/lib/go/src/github.com/drone-runner-kube/release/linux/arm64/drone-runner-kube /usr/bin/drone-runner-kube
 
COPY clean-runner /usr/bin/clean-runner
# COPY compose-data /usr/bin/compose-data
# COPY compose-data /usr/bin/compose-data
COPY build-keys /usr/bin/build-keys

RUN /bin/ln -fsv /mnt/volumes/configmaps/drone-runner-exec.env /etc/container/drone-runner-exec.env \
 && /bin/ln -fsv /mnt/volumes/container/drone-runner-exec.env /mnt/volumes/configmaps/drone-runner-exec.env

RUN /bin/ln -fsv /mnt/volumes/configmaps/drone-cli.env /etc/container/drone-cli.env \
 && /bin/ln -fsv /mnt/volumes/container/drone-cli.env /mnt/volumes/configmaps/drone-cli.env
 
RUN /bin/ln -fsv /mnt/volumes/configmaps/kubectl.cfg /etc/container/kubectl.cfg \
 && /bin/ln -fsv /mnt/volumes/container/kubectl.cfg /mnt/volumes/configmaps/kubectl.cfg \
 && /bin/mkdir -p /home/$USER/.kube \
 && /bin/ln -fsv /etc/container/kubectl.cfg /home/$USER/.kube/config
 
#  RUN /bin/mkdir -p /home/$USER/.config/ca \
#  && /bin/mkdir -p /home/$USER/.config/git

# RUN /bin/ln -fsv /etc/container/gitconfig /etc/gitconfig \
#  && /bin/ln -fsv /mnt/volumes/configmaps/gitconfig /etc/container/gitconfig \
#  && /bin/ln -fsv /mnt/volumes/container/gitconfig /mnt/volumes/configmaps/gitconfig

# RUN /bin/ln -fsv /mnt/volumes/secrets/git-credentials /etc/container/git-credentials \
#  && /bin/ln -fsv /mnt/volumes/container/git-credentials /mnt/volumes/secrets/git-credentials

# RUN /bin/ln -fsv /mnt/volumes/secrets/client-auth.crt /etc/container/client-auth.crt \
#  && /bin/ln -fsv /mnt/volumes/container/client-auth.crt /mnt/volumes/secrets/client-auth.crt 

# RUN /bin/ln -fsv /mnt/volumes/secrets/client-auth.key /etc/container/client-auth.key \
#  && /bin/ln -fsv /mnt/volumes/container/client-auth.key /mnt/volumes/secrets/client-auth.key



# ╭―
# │ CONFIGURATION
# ╰――――――――――――――――――――
RUN chown -R $USER:$USER /home/$USER
USER $USER
RUN /bin/mkdir -p /tmp/podman-run-1001/podman
RUN /usr/bin/podman system connection add sock unix:///tmp/podman-run-1001/podman/podman.sock
RUN /usr/bin/podman system connection default sock

VOLUME /mnt/volumes/backup
VOLUME /mnt/volumes/configmaps
VOLUME /mnt/volumes/container
VOLUME /mnt/volumes/secrets
VOLUME /mnt/volumes/logs
VOLUME /mnt/volumes/source
EXPOSE 3000/tcp
WORKDIR /home/$USER


# # [Issue: Drop WETTY interface in favor of Bastion](https://github.com/gautada/drone-runner-container/issues/29)
# EXPOSE 8080/tcp
# [Issue: Drop WETTY interface in favor of Bastion](https://github.com/gautada/drone-runner-container/issues/29)
# RUN /usr/bin/yarn global add wetty
# Setup UNIX sockert support for podman.


