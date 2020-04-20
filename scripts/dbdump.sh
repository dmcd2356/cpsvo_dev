#!/bin/bash

# if not exported, set the location of where drupal execution & development files are
# path to the desired base location from which drupal will run
# (this path will be created by this script)
if [ -z ${DRUPAL_RUN} ]; then
  DRUPAL_RUN="/home/$USER/drupal"
fi

# path where all development files to use are kept
# this makes it a requirement to have a development directory and to be running this script from it.
VALUE=`pwd`
if [ "${VALUE##*/}" != "scripts" ]; then
  echo "ERROR: This script must be run from the 'scripts' subfolder of your drupal development folder."
  echo "       For info on the structure of this folder, re-enter the command with the -h option."
  exit 1
fi
# this sets it to parent dir of the scripts dir
DRUPAL_DEV="${VALUE%/*}"
DRUPAL_DB="${DRUPAL_DEV}/database"

# name of database
DB_NAME="vsfs_db"

# base name for file output
DRUPAL_FILE="vsfsdb"

function setup_env
{
  # define the environment to run the roslaunch command in
  ENV=""
  ENV+=" -e HOSTNAME=766fb696fb64"
  ENV+=" -e MYSQL_DATABASE=vsfs_db"
  ENV+=" -e MYSQL_USER=vsfsuser"
  ENV+=" -e MYSQL_PASSWORD=vsfspass"
  ENV+=" -e MYSQL_ROOT_PASSWORD=root"
  ENV+=" -e MYSQL_MAJOR=8.0"
  ENV+=" -e MYSQL_VERSION=8.0.19-1debian9"
  ENV+=" -e PWD=/"
  ENV+=" -e HOME=/root"
  ENV+=" -e GOSU_VERSION=1.7"
  ENV+=" -e TERM=xterm"
  ENV+=" -e SHLVL=1"
#  ENV+=" -e affinity:container==dc71f058c5315f6f8e8dbd6e7bbfdf5c66e3ed22e275a5792b5d038f68c486de"
#  ENV+=" -e PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
#  ENV+=" -e _=/usr/bin/env"
}

OPTIONS="--default-character-set=utf8 --add-drop-table"
LOGIN="-u vsfsuser -pvsfspass"
OUTPUT="--result-file=/docker-entrypoint-initdb.d/${DRUPAL_FILE}.sql"

# dump current database to shared folder in docker, then place in DRUPAL_DEV location
docker exec ${ENV} drupal_db_1 mysqldump ${LOGIN} ${OPTIONS} ${DB_NAME} ${OUTPUT}

# copy name from docker shared folder to local folder
#timestamp=$(date +%Y-%m-%d_%H-%M-%S)
timestamp=$(date +%m-%d)
cp ${DRUPAL_RUN}/dump/${DRUPAL_FILE}.sql ${DRUPAL_DB}/${DRUPAL_FILE}-${timestamp}.sql
