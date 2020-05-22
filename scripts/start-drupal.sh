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
#     - Advanced -> Host:  IPADDR
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
# RUNNING THE CONTAINERS IN BACKGROUND:
#
# You can also run this script in the background by adding a "-d" option to the command.
# If you then wish to attach a terminal to it for viewing output you can enter the command:
#
#     docker attach <container_name>
#
# Where <container_name> is either drupal_www_1 (for the PHP/web server) or drupal_db_1
#   (for the database container). Note that you can't connect to them both with the same
#   terminal, and once a terminal is connected the only way to detach without killing the
#   container is to close the terminal.
#
# On the other hand, if you started the containers in normal mode, you can send to run in
#   the background by entering a ctrl-Z, followed by the command: bg
#
#-------------------------------------------------------------------------------------
#
# ACCESSING THE RUNNING CONTAINERS:
#
# If you need to access the files in the running contaioners, you can do so using the command:
#
#     docker exec -it <container_name> bash
#
# This will allow you access to the filesystem for either drupal_www_1 or drupal_db_1.
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

# finds the ip address for a given interface
#
# $1 = name of interface to find the ip address of
#
# returns: $IPADDR = the ip address for the corresponding interface (empty if not found)
#
function find_ipaddr
{
  # this will get the list of all interfaces with their corresponding settings, including the ip addr
  IPADDR=""
  local match=0
  local iface=""
  while IFS= read -r line; do
    local new_iface=0
    # look for the start of an interface definition
    if [[ ${line} != " "* ]]; then
      new_iface=1
      iface=$(echo ${line} | cut -d" " -f2 | cut -d":" -f1)
      if [ ${match} -eq 1 ]; then
        break;
      fi
    else
      # skip all lines until we find the interfcae we're looking for
      if [ "${iface}" != "$1" ]; then
        continue
      fi
      match=1
      # remove leading space & trim to 1st 2 fields
      line="$(echo -e "${line}" | sed -e 's/^[[:space:]]*//' | cut -d " " -f 1,2)"
      # now skip until we find the line that defines the inet address
      if [ "${line:0:5}" != "inet " ]; then
        continue
      fi
      IPADDR=$(echo ${line} | cut -d" " -f2 | cut -d"/" -f1)
      break
    fi
  done < <(ip addr)
}

# find the default interfaces and the ip addresses that go along with them
function find_network_addr
{
  # this will get a list of the names of the default interfaces
  IPLIST=""
  COUNT=0
  local ifclist=$(route | grep default | cut -c 73-)
  local array=($ifclist)
  for index in ${!array[@]}; do
    iface=${array[${index}]}
    find_ipaddr ${iface}
    if [[ "${IPADDR}" != "" ]]; then
      if [ ${COUNT} -eq 0 ]; then
        IPLIST="    ${IPADDR}  ${iface}"
      else
        IPLIST=$(printf "${IPLIST}\n    ${IPADDR}    ${iface}")
      fi
      COUNT=$(( COUNT + 1 ))
    fi
  done
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

BACKGROUND=0
ENTRY=()
while [[ $# -gt 0 ]]; do
  key="$1"
  case ${key} in
    -d)
      BACKGROUND=1
      shift
      ;;
    -h|--help)
      echo "This script starts up a pair of docker containers that make up a portion of"
      echo " a LAMP stack for a Drupal codebase. Following this script's completion, you should"
      echo " then run dbload.sh to load the database into the running instance of MySQL."
      echo " It is assumed that you have downloaded all the cpsvo_dev project files and are"
      echo " running this script from the scripts subdirectory of it."
      echo
      echo "After this script completes you should run dbload.sh to load the database corresponding"
      echo " to the codebase you are using if you have not loaded a database yet. You should also"
      echo " run copyimages.sh to copy over any user images you have placed in the images folder"
      echo " and also clamav_start.sh to startup the ClamAV anti-virus software in the drupal codebase."
      echo " You can then run Chrome or Firefox set to the location of either the ip address of"
      echo " the host system or https://127.0.0.1. It will probably complain about the self-signed"
      echo " certificate, but you can ignore that and tell it you accept the risk and continue."
      echo " If you loaded a new database, Drupal will indicate you need to initialize the"
      echo " database to continue. You will need to specify the following settings:"
      echo
      echo " - Database name:     vsfs_db"
      echo " - Database username: vsfsuser"
      echo " - Database password: vsfspass"
      echo " - Advanced -> Host:  127.0.0.1 or the IP addr of the host system"
      echo " - Advanced -> Port:  3306"
      echo
      echo "After the database has been setup, Drupal will now display your CPS-VO sandbox."
      echo " (there may be some additional configuring necessary)."
      echo
      echo "At this point you should now also be able to run MySQL Workbench and PHPStorm"
      echo " and configure them for viewing and editing the database and codebase correspondingly."
      echo " You can shut down the docker containers when you are done (ctrl-C will exit cleanly"
      echo " if you are not running in background) and restart them with this same start-drupal.sh"
      echo " and it will continue where you left off - no re-installing or configuring."
      echo
      echo "The following arguments are optional:"
      echo "  -h  : display this help information"
      echo "  -d  : run the script in the background"
      echo
      echo "The following directory structure is used under the main development folder:"
      echo "  - scripts  - contains all necessary script files (including this one)"
      echo "  - docker   - contains the Docker files to use (Dockerfile and docker-compose.yml)"
      echo "  - database - contains the database file to load"
      echo "  - images   - contains the themes and user image files to be copied over (optional)"
      echo "  - src      - contains the php codebase files (will be pulled in from SVN if not found)"
      echo "  - certificate - contains the certificate files for https (will be created if not found)"
      echo "  - config   - contains the files to be copied to docker container (will be created if not found)"
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

# adding some needed directories
echo "- adding webform amd tmp directories to mounted codebase"
if [ ! -d ${DOCKER_DRUPAL_PATH}/sites/default/files/webform ]; then
  mkdir -p ${DOCKER_DRUPAL_PATH}/sites/default/files/webform
fi
if [ ! -d ${DOCKER_DRUPAL_PATH}/sites/default/files/tmp ]; then
  mkdir -p ${DOCKER_DRUPAL_PATH}/sites/default/files/tmp
fi

# set ownership of the mounted drupal codebase to the www-data group and set the permissions
echo "- changing ownership and permissions of mounted codebase"
sudo chgrp -R www-data ${DOCKER_DRUPAL_PATH}
sudo chmod -R 2770 ${DOCKER_DRUPAL_PATH}
sudo chmod g-w ${DOCKER_DRUPAL_PATH}/sites/default

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
find_network_addr
echo "------------------------"
if [ ${COUNT} -eq 0 ]; then
  echo " IPADDR = 127.0.0.1"
elif [ ${COUNT} -eq 1 ]; then
  echo " IPADDR = ${IPLIST}"
else
  echo " IPADDR is one of the following:"
  echo "${IPLIST}"
fi
echo "------------------------"

# start the docker containers anew
echo "- starting LAMP docker containers"
cd ${DRUPAL_RUN}
if [ ${BACKGROUND} -ne 0 ]; then
  # run in background
  docker-compose up -d --build 
else
  # run in foreground (abort-on-container-exit prevents 1 container from running if the other failed)
  docker-compose up --build --abort-on-container-exit 
fi
