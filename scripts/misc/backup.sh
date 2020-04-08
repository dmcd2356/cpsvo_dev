#!/bin/bash

# This is used to backup the docker and scripts files to the shared directory

DRUPAL_SHARED="/media/sf_CPS-VO/Drupal" # location of shared Drupal development folder on the VM
DRUPAL_DEV="/home/$USER/drupal-dev"     # location of development files folder being backed up

# copies the specified subdir from DRUPAL_DEV to DRUPAL_SHARED location.
# if the folder already exists, it will remove the current contents first.
# if the folder does not exist, it will create it
#
# $1 = name of subfolder in DRUPAL_DEV to copy
#
function copydir
{
  # remove the current contents in the shared folder
  if [ -d ${DRUPAL_SHARED}/$1 ]; then
    sudo rm -Rf ${DRUPAL_SHARED}/$1
  fi
  sudo mkdir -p ${DRUPAL_SHARED}/$1
  echo "- copying files from: $1"
  sudo cp -a ${DRUPAL_DEV}/$1/* ${DRUPAL_SHARED}/$1
}

# check if this is run from a VM and we have a shared dir to the Drupal development files
if [ -z ${DRUPAL_SHARED} ] || [ ! -d ${DRUPAL_SHARED} ]; then
  echo "Shared directory not found: ${DRUPAL_SHARED}"
  exit 1
fi

# copy over the desired subdirs
copydir docker
copydir scripts
copydir sites-default-files
  
# only copy the compressed database file if it exists and the shared location does not have a copy
if [ -f ${DRUPAL_DEV}/database/vo_db.sql.tar.gz ] && [ ! -f ${DRUPAL_SHARED}/database/vo_db.sql.tar.gz ]; then
  echo "- copying compressed database file"
  sudo mkdir -p ${DRUPAL_SHARED}/database
  sudo cp ${DRUPAL_DEV}/database/vo_db.sql.tar.gz ${DRUPAL_SHARED}/database
fi
