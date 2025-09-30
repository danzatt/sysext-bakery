#!/bin/bash

CONTAINER_IMAGE=$1
shift

ARGS=("--rm" "--volume" "/tmp:/tmp" "--volume" "$PWD:/app" --entrypoint "" --workdir "/app" "--privileged")
# Extra "sh -c" is needed to only export the exported variables
for VARNAME in $(bash -c 'compgen -v | grep -vE "(DIRSTACK|HOME|HOSTNAME|LOGNAME|MAIL|OLDPWD|PATH|PWD|USER|USERNAME|XDG_DATA_DIRS|BASH|EPOCH|RANDOM)"'); do
  set +u
  VAL="${!VARNAME}"
  set -u
  ARGS+=("--env" "${VARNAME}=${VAL}")
done

# echo "${ARGS[@]}"
# sudo docker run "${ARGS[@]}" --entrypoint "" "$CONTAINER_IMAGE" env

docker run "${ARGS[@]}" "$CONTAINER_IMAGE" "$@"
