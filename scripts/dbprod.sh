#!/bin/bash

# This dumps the database from the CPS-VO production server and copies it to the database folder
#  in the drupal development directory.
#
# This assumes you have been given access to the server with your ssh key and have setup a
#  ~/.ssh/config file with the following info (replace <username> as appriopriate):
#
#   #DEVELOPMENT
#   Host dev
#   HostName 129.59.104.45
#   Compression yes
#   Port 42422
#   IdentityFile ~/.ssh/id_rsa
#   Protocol 2
#   User <username>

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

if [ ! -f ~/.ssh/config ]; then
  echo "ERROR: The required ~/.ssh/config file was not found."
  exit 1
fi

echo "This will download the database contents of the current production CPS-VO image"
echo " into your drupal development's database directory."
read -p "Do you wish to proceed? (Y/n): " SELECT
if [ "${SELECT}" != "Y" ] && [ "${SELECT}" != "y" ]; then
  echo "- exiting."
  exit 1
fi

echo "- generating zipped dump of production database"
echo "  (you will be prompted for your login password)"
ssh dev sudo -S copydb.sh

echo "- copying vocypher.sql.gz to database folder"
cd ${DRUPAL_DB}
scp dev:~/vocypher.sql.gz .

echo "- extracting contents of vocypher.sql.gz"
gunzip vocypher.sql.gz --keep
timestamp=$(date +%m-%d)
mv vocypher.sql vocypher-${timestamp}.sql
