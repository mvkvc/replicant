#! /bin/sh

ENGINE=podman

if [ $# -gt 2 ] || ([ $# -eq 1 ] && [ "$1" != "-f" ]); then
    echo "Usage: $0 [-f]"
    exit 1
fi

if [ "$1" = "-f" ]; then
    (cd ./apps/worker_sdk && npm run build)
    $ENGINE compose down --remove-orphans
    $ENGINE compose build --no-cache
fi

$ENGINE compose up

