#!/bin/bash

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

if [ ! -d /opt/svn ]; then
  sudo mkdir -p /opt/svn
fi

# checkout drupal code from svn and place in the download location
  echo "- checking out latest codebase from SVN"
  echo "  (if prompted, enter your username and password for VOCYPHER)"
svn checkout https://svn.isis.vanderbilt.edu/VOCYPHER/trunk/websites/portal/drupal ${DRUPAL_DEV}/src &> /dev/null
