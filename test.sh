#!/usr/bin/env bash
DOCKERFILES=$(find * -type f -name Dockerfile)
IMAGES=$(echo ${DOCKERFILES}|sed 's~/Dockerfile~~g')
echo ${IMAGES}

ALL_IMAGES=$(docker images -q)

for img in $IMAGES
do
    for cont in $ALL_IMAGES
    do
        one=$(docker inspect $cont|jq '.[0].RepoTags')
        echo "FOO: $one"
        ret=$(docker inspect $cont|jq ".[0].RepoTags | index(\"ivonet/$img:latest\")")
        echo "BAR: $ret"
        if [ "$ret" != "null" ]
        then
            echo "BAZ"
        fi
    done
done



