#!/bin/sh

BASEDIR=`pwd`

make clean && make && \

cd $BASEDIR/base && npm install && npm link && \

cd $BASEDIR/api && npm link apiaxle-base && npm install && npm link && \

cd $BASEDIR/proxy && npm link apiaxle-base && npm install && \

cd $BASEDIR/repl && npm link apiaxle-base && npm link apiaxle-api && npm install && \
echo "#!/usr/bin/env node" > apiaxle && cat ./apiaxle.js >> apiaxle && \
chmod a+x apiaxle && mv apiaxle $BASEDIR/
