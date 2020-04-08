#!/bin/bash

# This script starts up a pair of docker containers: one that contains the apache web server
#  and PHP installation (drupal_www_1) and the other that contains the MySQL database
#  server (drupal_db_1). Together they will run the stack for a Drupal codebase.
#
# It assumes the following directory structure exists under the folder you define as ${DRUPAL_DEV):
# - scripts  - contains all necessary script files (including this one)
# - docker   - contains the Docker files to use (Dockerfile and docker-compose.yml)
# - database - contains either the database file vo_db.sql or a zipped version vo_db.sql.tar.gz
# - images   - contains the image files to be copied over (themes and user files)
# - src      - contains the php codebase files (will be pulled in from SVN if not found)
# - config   - contains the php config file and self-signed certificate files for https
#              (certificate files will be generated if not found)
#
# Just before the docker images begin to run, this script will display the value for IPADDR.
#  Use this value below when referencing the database setup and the web browser setup.
#  If this is being installed directly on the host (not a VM) or the VM is set for NAT type
#  Networking, the IPADDR value will be 127.0.0.1 (localhost). If you set this up on a VM
#  and set the Network interface to Bridged adapter, you will need to use the IPADDR value
#  indicated above.
#
# NOTE: The reason you may wish to set the VM for Bridged adapter is that your host machine
#  will also be able to access to your Drupal installation from a web browser. Because the
#  IP assignment is not a static value, you may have to change the address used to access it
#  occaisionally. This will mean not only changing the address value used in the web browser,
#  but you will also have to change the IP addr value defined for "$db_url" found in the file
#  drupal/sites/default/settings.php in the drupal source, which will give access to the database.
#
# AFTER THIS SCRIPT HAS BEEN RUN:
#
# * if a database has not been loaded yet, or you want to restore a previous database version,
#     run dbload.sh to install the database that should be at: ${DRUPAL_DEV}/database.
#
# * open a web browser and point it to: https://127.0.0.1/admin to access the Drupal interface
#     (replace with IPADDR value if running on VM set in Bridged Adapter mode).
#   The first time you run this, you will probably need to prompt the browser to allow access
#     to the site since it may complain about the certificate not being secure. This is because
#     it is using a self-signed (snake-oil) certificate, but it is safe since this is just being
#     used on your local machine.
#   Drupal will indicate the database needs configuring, so it will prompt for the language
#     selection and then the database info. Make sure to click on the 'Advanced' selection
#     to open the selections for the MySQL Host location. The settings should be the following
#     (as specified in the docker-compose.yml file):
#
#     - Database name:     vsfs_db
#     - Database username: vsfsuser
#     - Database password: vsfspass
#     - Advanced -> Host:  127.0.0.1   (use IPADDR value if running VM in Bridged adapter mode)
#     - Advanced -> Port:  3306
#
#   When complete it will indicate a database is already installed, select view existing database
#
#   If you get an error and it indicates you may have the wrong database name or password, check
#     the drupal/drupal/sites/localhost/settings.php file and look for the $db_url definition.
#     It should be set to:
#
#     $db_url = 'mysqli://vsfsuser:vsfspass@localhost/vsfs_db';
#
#-------------------------------------------------------------------------------------
#
# NOTE: You can also run this script in the background by adding a "-d" option to the command.
#
#-------------------------------------------------------------------------------------
#
# NOTE: if your ubuntu host is currently running a web server (apache, nginx) using port 443
#       or a database server using port 3306, you must stop their service prior to running this,
#       since the docker container includes these services.
#
#-------------------------------------------------------------------------------------


# The following paths should be tailored to your situation:
#
# path to the desired base location from which drupal will run
# (this path will be created by this script)
DRUPAL_RUN="/home/$USER/drupal"


# this copies the specified file over to the PHP container's shared config folder for Dockerfile
#  to access and relocate the files to their proper locations.
#
# $1 = 0 if optional, 1 if required
# $2 = filename to copy
#
function copy_to_php_share
{
  local config_file=$2
  if [ ! -f ${config_file} ]; then
    echo "WARNING: file not found: ${config_file}"
    if [ $1 -eq 1 ]; then
      exit 1
    fi
    read -p "Do you wish to run anyway? (Y/n): " RESPONSE
    if [ "${RESPONSE}" != "Y" ] && [ "${RESPONSE}" != "y" ]; then
      exit 1
    fi
    echo "# DUMMY FILE" > ${config_file}
  else
    echo "- copying file to development config folder: ${config_file}"
  fi
  cp ${config_file} ${DRUPAL_CONFIG}
}

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

export DRUPAL_RUN
export DRUPAL_DEV

OPTIONS=""
ENTRY=()
while [[ $# -gt 0 ]]; do
  key="$1"
  case ${key} in
    -d)
      OPTIONS="-d"
      shift
      ;;
    -h|--help)
      echo "This script starts up a pair of docker containers that make up a portion of"
      echo " a LAMP stack for a Drupal codebase. Following this script's completion, you should"
      echo " then run dbload.sh to load the database into the running instance of MySQL."
      echo
      echo "After that you should be able to run Chrome or Firefox set to 127.0.0.1/admin"
      echo " to view your CPS-VO Drupal sandbox (the database will need to be specified and"
      echo " there may be some configuring necessary. Also, you should now be able to run"
      echo " MySQL Workbench and PHPStorm and configure them for viewing and editing the"
      echo " database and codebase correspondingly."
      echo
      echo "The following arguments are optional:"
      echo "  -h  : display this help information"
      echo "  -d  : run the script in the background"
      echo "  -f <path>  : specify the folder location of the development files (explained below)"
      echo "               (default = /home/$USER/drupal-dev)"
      echo
      echo "It assumes the following directory structure exists under the main development folder:"
      echo "  - scripts  - contains all necessary script files (including this one)"
      echo "  - docker   - contains the Docker files to use (Dockerfile and docker-compose.yml)"
      echo "  - database - contains the database file to load (must be loaded after this script runs)"
      echo "  - images   - contains the themes and user image files to be copied over (optional)"
      echo "  - src      - contains the php codebase files (will be pulled in from SVN if not found)"
      echo "  - certificate - contains the certificate files for https (will be created if not found)"
      exit 0
      ;;
    *)
      ENTRY+=("$1")
      shift
      ;;
  esac
done

# since some commands may need sudo access, let's get the user password out of the way
sudo echo

# The following paths define locations in the drupal development folder that are used
DOCKER_PATH="${DRUPAL_DEV}/docker"      # location of Docker files
DRUPAL_CONFIG="${DRUPAL_DEV}/config"    # location of PHP config and self-signed certificate files
DRUPAL_IMAGES="${DRUPAL_DEV}/images"    # location of any drupal image files to copy
DRUPAL_SRC="${DRUPAL_DEV}/src"          # location of the drupal source code (downloaded from SVN)
DRUPAL_SCRIPTS=`pwd`                    # location of script files (where this one resides)

# the following are paths that are shared with the drupal container
# (these must match the 'volumes' entries in the docker-compose.yml file)
DOCKER_DRUPAL_PATH="${DRUPAL_RUN}/drupal"
# NOTE: had a problem in accessing this folder in PHP container if we make it outside the confines
#       of $DOCKER_DRUPAL_PATH since it is confined to access from that folder as its root,
#       so Dockerfile cannot see any folder outside of this.
CONFIG_FOLDER=${DOCKER_DRUPAL_PATH}/config


# verify path selections are valid
if [ ! -d ${DRUPAL_RUN} ]; then
  mkdir -p ${DRUPAL_RUN}
fi
if [ ! -f ${DOCKER_PATH}/docker-compose.yml ] || [ ! -f ${DOCKER_PATH}/Dockerfile ]; then
  echo "ERROR: ${DOCKER_PATH} does not contain the drupal docker files required."
  echo "       This path must exist and must contain the following files:"
  echo "       - docker-compose.yml"
  echo "       - Dockerfile"
  echo "       - all configuration files for docker containers"
  exit 1
fi
if [ ! -d ${DRUPAL_SRC} ] || [ ! -f ${DRUPAL_SRC}/index.php ]; then
  echo "ERROR: drupal folder invalid: ${DRUPAL_SRC}"
  echo "       the path ${DRUPAL_SRC} must exist and must contain the downloaded Drupal codebase"
  read -p "Do you wish to download from SVN now? (Y/n): " RESPONSE
  if [ "${RESPONSE}" != "Y" ] && [ "${RESPONSE}" != "y" ]; then
    exit 1
  fi
  ./svncheckout.sh
fi

# create the drupal development config directory if it doesn't exist to hold all files to be
#  copied over to the apache/php container shared config directory.
if [ ! -d ${DRUPAL_CONFIG} ]; then
  mkdir -p ${DRUPAL_CONFIG}
fi

# copy configuration files over to the PHP container's shared config folder
#copy_to_php_share 0 ${DOCKER_PATH}/zz-app.ini
copy_to_php_share 0 ${DOCKER_PATH}/clamd.conf

# stop any current docker containers running
cd ${DRUPAL_RUN}
STATUS=`docker-compose ps | grep ^drupal_ | grep Up`
if [ "${STATUS}" != "" ]; then
  echo "WARNING: docker images already running"
  read -p "Do you wish to terminate current containers and restart? (Y/n): " RESPONSE
  if [ "${RESPONSE}" != "Y" ] && [ "${RESPONSE}" != "y" ]; then
    exit 1
  fi
  echo "- stopping active docker containers"
  docker-compose stop
fi

# make sure we have the current folder mounted: if our DOCKER_DRUPAL_PATH is already mounted, unmount it.
# then mount the specified folder to it.
echo "- mounting the drupal codebase at: ${DOCKER_DRUPAL_PATH}"
is_mounted=`less /proc/self/mountinfo | grep ${DOCKER_DRUPAL_PATH}`
if [ "${is_mounted}" != "" ]; then
  PREV_MOUNT=`echo ${is_mounted} | cut -d ' ' -f4`
  sudo umount ${DOCKER_DRUPAL_PATH}
  echo "  unmounted: ${PREV_MOUNT}"
fi
mkdir -p ${DOCKER_DRUPAL_PATH}
sudo mount --bind ${DRUPAL_SRC} ${DOCKER_DRUPAL_PATH}
echo "    mounted: ${DRUPAL_SRC}"

# set ownership of the mounted drupal codebase to the www-data group and set the permissions
echo "- changing ownership and permissions of mounted codebase"
sudo chgrp -R www-data ${DOCKER_DRUPAL_PATH}
sudo chmod -R 2770 ${DOCKER_DRUPAL_PATH}
sudo chmod g-w ${DOCKER_DRUPAL_PATH}/sites/default
if [ ! -d ${DOCKER_DRUPAL_PATH}/sites/default/files/webform ]; then
  mkdir -p ${DOCKER_DRUPAL_PATH}/sites/default/files/webform
fi

# make sure a settings.php file exists in the drupal/sites/default folder
PHP_SETTINGS="${DOCKER_DRUPAL_PATH}/sites/default/settings.php"
if [ ! -f ${PHP_SETTINGS} ] && [ -f ${DOCKER_DRUPAL_PATH}/sites/default/default.settings.php ]; then
  echo "- creating a default settings.php entry"
  cp ${DOCKER_DRUPAL_PATH}/sites/default/default.settings.php ${PHP_SETTINGS}
fi
# modify settings.php to remove warning about http request failures
RESPONSE=`grep drupal_http_request_fails ${PHP_SETTINGS}`
if [ "${RESPONSE}" == "" ]; then
  echo "\$conf['drupal_http_request_fails'] = FALSE;" >> ${PHP_SETTINGS}
fi
sudo chmod g-w ${PHP_SETTINGS}

# now copy the docker files to the mounted directory
echo "- copying docker files to mount location"
cp ${DOCKER_PATH}/docker-compose.yml ${DRUPAL_RUN}
cp ${DOCKER_PATH}/Dockerfile ${DOCKER_DRUPAL_PATH}

# Append settings to the PHP config file /var/www/html/.htaccess
# NOTE: we do this instead of copying an ini file to the /usr/local/etc/php/conf.d/ path
#       in the PHP container because that doesn't seem to work.
htaccess_patch="${DOCKER_PATH}/htaccess_patch.ini"
is_set=`grep "php_value max_input_vars 4000" ${DOCKER_DRUPAL_PATH}/.htaccess`
if [ "${is_set}" == "" ] && [ -f ${htaccess_patch} ]; then
  echo "- adding patch to .htaccess file"
  cat ${htaccess_patch} >> ${DOCKER_DRUPAL_PATH}/.htaccess
fi

cd ${DRUPAL_SCRIPTS}

# copy any defined images to the drupal files folder
if [[ -d ${DRUPAL_IMAGES} ]]; then
  ./copyimages.sh
fi

# copy certificate and public key info over to mounted docker drupal directory so Dockerfile
#  has access to copy them to apache config locations.
# (if certificate info was not found, create a self-signed one)
if [ ! -f ${DRUPAL_CONFIG}/ssl-cert-snakeoil.key ]  ||
   [ ! -f ${DRUPAL_CONFIG}/ssl-cert-snakeoil.pem ]; then
  ./certificate.sh
  cp ${DRUPAL_DEV}/certificate/ssl-cert-snakeoil.key ${DRUPAL_CONFIG}
  cp ${DRUPAL_DEV}/certificate/ssl-cert-snakeoil.pem ${DRUPAL_CONFIG}
fi

# copy all the config files to the drupal/config dir so Dockerfile can access them
cd ${DRUPAL_CONFIG}
count=$(find . -type f | wc -l)
echo "- copying ${count} config files to: ${CONFIG_FOLDER}"
mkdir -p ${CONFIG_FOLDER}
cp ${DRUPAL_CONFIG}/* ${CONFIG_FOLDER}
sudo chgrp -R www-data ${CONFIG_FOLDER}
sudo chmod -R 770 ${CONFIG_FOLDER}

# show the IP address to tune to
IPADDR=""
IPLIST=$(hostname -I)
array=($IPLIST)
for index in ${!array[@]}; do
  ipnext=${array[${index}]}
  if [[ "${ipnext}" == "129.59."* ]]; then
    IPADDR=${ipnext}
  fi
done
echo "------------------------"
if [ "${IPADDR}" != "" ]; then
  echo " IPADDR = ${IPADDR}"
else
  echo " IPADDR = 127.0.0.1"
fi
echo "------------------------"

# start the docker containers anew
echo "- starting LAMP docker containers"
cd ${DRUPAL_RUN}
docker-compose up ${OPTIONS} --build --abort-on-container-exit 