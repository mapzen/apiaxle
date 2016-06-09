#!/bin/bash
base_src="base/apiaxle-base-$CIRCLE_TAG.tgz"
api_src="api/apiaxle-api-$CIRCLE_TAG.tgz"
proxy_src="proxy/apiaxle-proxy-$CIRCLE_TAG.tgz"
repl_src="repl/apiaxle-repl-$CIRCLE_TAG.tgz"

if [ ! \( -f $base_src -a -f $api_src -a -f $proxy_src -a -f $repl_src \) ] ; then
  echo "package version mis-match"
  echo "tagged release: $CIRCLE_TAG"
  echo "packages:"
  find . -name *.tgz -print
  exit 1
fi

dest="s3://mapzen.software/apiaxle/"

aws s3 cp $base_src $dest
aws s3 cp $api_src $dest
aws s3 cp $proxy_src $dest
aws s3 cp $repl_src $dest
