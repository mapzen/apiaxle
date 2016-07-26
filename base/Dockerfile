FROM mhart/alpine-node:4
RUN npm install -g coffee-script twerp supervisor
RUN apk add --update alpine-sdk python python-dev
WORKDIR /apiaxle/base
ADD . .
RUN npm install libxmljs && npm install && make clean && make
RUN apk del --purge alpine-sdk python python-dev
VOLUME /apiaxle/base
CMD coffee --watch --compile /apiaxle/base/index.coffee /apiaxle/base/app/ /apiaxle/base/lib/
