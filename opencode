#!/bin/bash

export LLAMA_SERVER_URL=${LLAMA_SERVER_URL:-http://[::]:4000/v1}
export LLAMA_MODEL=${LLAMA_MODEL:-opencode.code}
export DOCKER_IMAGE=${DOCKER_IMAGE:-opencode:latest}

extra_cmd=
if [ ! -z "${OPENCODE_CONFIG}" -a -f "${OPENCODE_CONFIG}" ]; then
    extra_cmd="-v ${OPENCODE_CONFIG}:${OPENCODE_CONFIG}:ro -e OPENCODE_CONFIG"
fi
export OPENCODE_CONFIG

export GIT_SSH_COMMAND="ssh -o StrictHostKeyChecking=no"

extra_opts=

# share ssh keys (dangerous)
if [ ! -z "$SSH_AUTH_SOCK" ]; then
    b_sock=$(readlink -f "$SSH_AUTH_SOCK")
    b_dir=${b_sock##*/}
    export C_SSH_AUTH_SOCK=/dev/shm/$b_dir
    extra_opts="-v $SSH_AUTH_SOCK:/dev/shm/$b_dir -e SSH_AUTH_SOCK=$C_SSH_AUTH_SOCK $extra_opts"
fi

# Share Docker socket if available and set DOCKER_HOST
if [ -S /var/run/docker.sock ]; then
    extra_opts="-v /var/run/docker.sock:/var/run/docker.sock $extra_opts"
    DOCKER_HOST=unix:///var/run/docker.sock
fi
export DOCKER_HOST

# Share containerd socket and config
if [ -S /run/containerd/containerd.sock ]; then
    extra_opts="-v /run/containerd/containerd.sock:/run/containerd/containerd.sock $extra_opts"
    CONTAINERD_ADDRESS=/run/containerd/containerd.sock
fi
export CONTAINERD_ADDRESS
if [ -d /etc/containerd ]; then
    extra_opts="-v /etc/containerd:/etc/containerd:ro $extra_opts"
fi

# Share git info
if [ -f ~/.gitconfig ]; then
    fn=$(readlink -f ~/.gitconfig)
    extra_opts="-v $fn:/home/node/.gitconfig:ro $extra_opts"
fi
if [ -f ~/.gitexcludes ]; then
    fn=$(readlink -f ~/.gitexcludes)
    extra_opts="$extra_opts -v $fn:/home/node/.gitexcludes:ro $extra_opts"
fi

# Share Docker config for registry authentication and buildx state
if [ -d ~/.docker ]; then
    extra_opts="-v $HOME/.docker:/home/node/.docker $extra_opts"
fi

HERE=$(readlink -f "${PWD}")
BDIR=${HERE##*/}
docker pull -q $DOCKER_IMAGE >/dev/null 2>&1 || { echo "problem fetching $DOCKER_IMAGE"; exit $?; }
ROCM_PATH=${ROCM_PATH:-~/therock-dist-linux-gfx1151-latest}
ROCM_PATH=$(readlink -f "$ROCM_PATH")
exec docker run --rm -it \
    $extra_opts \
    $DOCKER_RUN_OPTS \
    -e TERM \
    -e ALL_PROXX \
    -e HTTP_PROXY \
    -e HTTPS_PROX \
    -e TMPDIR=/workspace/$BDIR/.tmp \
    -e NODE_TLS_REJECT_UNAUTHORIZED=0 \
    -e NODE_OPTIONS="--max-old-space-size=4096" \
    -e UID=${EUID} \
    -e BDIR=/workspace/$BDIR \
    ${DOCKER_HOST:+-e DOCKER_HOST} \
    ${CONTAINERD_ADDRESS:+-e CONTAINERD_ADDRESS} \
    ${GIT_SSH_COMMAND:+-e GIT_SSH_COMMAND} \
    -e LLAMA_SERVER_URL \
    -e LLAMA_MODEL \
    -e GIT_AUTHOR_NAME \
    -e GIT_AUTHOR_EMAIL \
    -e GIT_COMITTER_NAME \
    -e GIT_COMITTER_EMAIL \
    -e GIT_EDITOR="true" \
    -e ROCM_PATH=/opt/rocm \
    -v $ROCM_PATH:/opt/rocm:ro \
    --ulimit memlock=-1:-1 \
    --ulimit stack=67108864:67108864 \
    --group-add=video \
    --ipc=host \
    --cap-add=SYS_PTRACE \
    --security-opt seccomp=unconfined \
    --group-add 986 \
    --group-add 109 \
    --group-add 992 \
    --device /dev/kfd \
    --device /dev/dri \
    --network=host \
    $extra_cmd \
    --name opencode-${LOGNAME}-${BDIR} \
    -v opencode-${LOGNAME}:/workspace \
    -v "${PWD}":/workspace/$BDIR \
        "$DOCKER_IMAGE" \
            $*
