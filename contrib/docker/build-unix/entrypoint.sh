#!/bin/bash
REPO="https://github.com/GIN-coin/gincoin-core.git"
SRC="/tmp/src"
BUILD="/build"
OPTIONS="$@"

git clone ${REPO} ${SRC} && cd ${SRC}

./autogen.sh && ./configure ${OPTIONS} && make

if [[ ! -f ${SRC}/src/gincoind ]]; then
    echo "Build failed"
    exit 1
fi

test -e ${SRC}/src/gincoind && cp ${SRC}/src/gincoind ${BUILD}/
test -e ${SRC}/src/gincoin-cli && cp ${SRC}/src/gincoin-cli ${BUILD}/
test -e ${SRC}/src/gincoin-tx && cp ${SRC}/src/gincoin-tx ${BUILD}/
test -e ${SRC}/src/qt/gincoin-qt && cp ${SRC}/src/qt/gincoin-qt ${BUILD}/