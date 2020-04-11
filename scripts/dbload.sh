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
DRUPAL_DB="${DRUPAL_DEV}/database"

if [ ! -d ${DRUPAL_DB} ]; then
  echo "ERROR: directory not found: ${DRUPAL_DB}"
  exit 1
fi

# get list of candidates in database path
cd ${DRUPAL_DB}
list=$(find *.sql -type f)
array=(${list})
count=${#array[@]}

# exit if no files found in directory
if [ ${count} -eq 0 ]; then
  echo "ERROR: No sql file found in: ${DRUPAL_DB}"
  exit 1
fi

# check if filename was passed
if [ $# -ne 0 ]; then
  DRUPAL_FILE=$1
  if [ ! -f ${DRUPAL_FILE} ]; then
    echo "ERROR: ${DRUPAL_DB}/${DRUPAL_FILE} not found"
    exit 1
  fi
else
  if [ ${count} -eq 1 ]; then
    # only 1 file found, use it
    DRUPAL_FILE=${list}
  else
    # multiple files found - let user choose
    echo "No SQL file was passed."
    echo "Choose from one of the following files found in: ${DRUPAL_DB}"
    index=0
    for file in "${array[@]}"
    do
    	echo "  ${index} - ${file}"
    	index=$(( index + 1 ))
    done
    read -p "Enter the number of the file to use (blank entry to EXIT): " SELECT
    if [ "${SELECT}" == "" ]; then
      echo "- aborting."
      exit 0
    fi
    # check for invalid inputs
    if ! [[ ${SELECT} =~ ^[0-9]+$ ]]; then
      echo "Invalid selection. Aborting"
      exit 0
    fi
    if [ ${SELECT} -lt 0 ] || [ ${SELECT} -ge ${count} ]; then
      echo "Invalid selection. Aborting"
      exit 0
    fi
    DRUPAL_FILE=${array[${SELECT}]}
  fi
  read -p "About to load file ${DRUPAL_FILE}. Proceed? (Y/n): " SELECT
  if [ "${SELECT}" != "Y" ] && [ "${SELECT}" != "y" ]; then
    echo "- aborting."
    exit 1
  fi
fi

echo "- loading database file: ${DRUPAL_FILE}"
echo "  --- Please wait for the database to load. This may take several minutes ---"
mysql -h localhost -u vsfsuser -pvsfspass --silent -P 3306 --protocol=tcp vsfs_db < ${DRUPAL_FILE}
echo "- database load complete !"
