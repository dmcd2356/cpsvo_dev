#!/bin/bash

# if not exported, set the location of where drupal runs from
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

# copy files in specified directory from $SRC_PATH to $DST_PATH
# $1 = sub-directory of source to copy from
# $2 = sub-directory of dest to copy to
# 
function copyfiles
{
  local SRC=${SRC_PATH}/$1
  local DST=${DST_PATH}/$2
  
  # verify destination location exists
  if [[ ! -d ${DST} ]]; then
    echo "- drupal path not found: ${DST}"
    exit 1
  fi

  # skip if source folder does not exist or is empty
  if [[ ! -d ${SRC} ]]; then
    echo "- no source folder: ${SRC}"
    exit 0
  fi
  cd ${SRC}
  count=$(find . -type f | wc -l)
  if [[ ${count} -le 0 ]]; then
    echo "- no files found at: ${SRC}"
    exit 0
  fi

  echo "- copying ${count} image files to: ${DST}"
  cp -r ${SRC}/* ${DST}
  sudo chown -R www-data:www-data ${DST}
  sudo chmod g+wx ${DST}      # the directories must be group writable & executable
  sudo chmod -R g+r ${DST}/*  # the files only need to have group read access
}

# exit if no image files to copy
SRC_PATH="${DRUPAL_DEV}/images"
if [[ ! -d ${DRUPAL_DEV}/images ]]; then
  echo "- (no image files to copy)"
  exit 0
fi

# define the location of where we are copying image files from and to
DST_PATH="${DRUPAL_RUN}/drupal/sites"

# copy images to the drupal files folder
copyfiles "users" default/files
