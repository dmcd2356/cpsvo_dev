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

# we build the config file from a template
TEMPLATE_FILE=${DRUPAL_DEV}/docker/ssmtp.tmpl
CONFIG_FILE=${DRUPAL_DEV}/config/ssmtp.conf

if [ -f ${CONFIG_FILE} ]; then
  echo "ssmtp.conf file already exists."
  read -p "Do you wish to modify settings? (Y/n): " SELECT
  if [ "${SELECT}" != "Y" ] && [ "${SELECT}" != "y" ]; then
    echo "- aborting."
    exit 0
  fi
fi

# copy the template file to the config file
if [ -f ${TEMPLATE_FILE} ]; then
  cp ${TEMPLATE_FILE} ${CONFIG_FILE}
else
  echo "ERROR: SMTP template file not found: ${TEMPLATE_FILE}"
  read -p "Continue without Gmail redirection? (Y/n): " SELECT
  if [ "${SELECT}" != "Y" ] && [ "${SELECT}" != "y" ]; then
    echo "- aborting."
  fi
  echo "DUMMY SSMTP CONFIG FILE!" > ${CONFIG_FILE}
  exit 0
fi

# get info from user
read -p "Enter IP address of smtp server: " IPADDR
read -p "Enter Gmail account to send all messages to (do NOT include @gmail.com): " GMAIL_DST
read -p "Enter Gmail account setup as server (do NOT include @gmail.com): " GMAIL_SRC
read -p "Enter password for the account: " GMAIL_PASS

# modify the entries in the config file
sed -i "s/IPADDR/${IPADDR}/g" ${CONFIG_FILE}
sed -i "s/GMAIL_DST/${GMAIL_DST}/g" ${CONFIG_FILE}
sed -i "s/GMAIL_SRC/${GMAIL_SRC}/g" ${CONFIG_FILE}
sed -i "s/GMAIL_PASS/${GMAIL_PASS}/g" ${CONFIG_FILE}

echo "- ssmtp.conf created !"
