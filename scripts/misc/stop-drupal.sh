#!/bin/bash

# This script stops the running docker-compose containers.

# if not exported, set the base location of where drupal is running from
if [ -z ${DRUPAL_RUN} ]; then
  DRUPAL_RUN="/home/$USER/drupal"
fi

# stop any current docker containers running
if [ ! -d ${DRUPAL_RUN} ]; then
  echo "- drupal directory '${DRUPAL_RUN}' not found"
fi

cd ${DRUPAL_RUN}
STATUS=`docker-compose ps | grep ^drupal_ | grep Up`
if [ "${STATUS}" != "" ]; then
  echo "- stopping active docker containers"
  docker-compose stop
else
  echo "- no docker-compose containers of drupal running"
fi
