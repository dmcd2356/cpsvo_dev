#!/bin/bash

# This script configures an Ubuntu 18.04 (VM or host) platform with the necessary tools to be
# able to run the docker Drupal stack. It will also install Chrome browser, MySQL Workbench,
# and PHPStorm if they are not already installed.
#
# Configuration for these applications are as follows:
#
# To configure MySQL Workbench for connection to docker container:
# - make sure drupal containers are running (use ./start_drupal.sh)
# - start MySQL Workbench up
# - click the + next to MySQL Connections to add a connection
# - set Username to: vsfsuser
# - click Store in Keychain under Password and enter: vsfspass
# - click Test Connection button to verify it connects
# - either import the vo_db.sql file into vo_db database in Workbench, or run the script: ./setdb.sh
#   (NOTE: this may take a few minutes to complete, so be patient)
#
# To configure PHPStorm for SVN access:
# - start PHPStorm (from command line it is simply: phpstorm)
# - select "Do not import settings"
# - Once it is up and running, activate license
# - select Get From Version Control
# - set Version control to Subversion
# - add repo: https://svn.isis.vanderbilt.edu/VOCYPHER/trunk/websites/portal/drupal
# - checkout files to ~/drupal/drupal
#
# To configure web browser to connect to Drupal: refer to start-drupal.sh.
#
#--------------------------------------------------------------------------------------------------

RESTART=0

# get the version of the specified program
#
# $1 = name of program command
# $2 = the (zero-based) index of the version command response that contains the version number
#
# Returns:
# $VERSION = version number (empty if not installed)
#
function get_version
{
  local COMMAND=$1
  local INDEX=$2
  VERSION=""

  local STATUS=`${COMMAND} --version 2> /dev/null`
  local ERROR=$?
  #echo "${STATUS}"
  if [ ${ERROR} -ne 0 ]; then
    #echo "- Command '${COMMAND}' returned error ${ERROR}"
    return 0
  fi
  if [ "${STATUS}" == "" ]; then
    #echo "- Command '${COMMAND}' was not found"
    return 0
  fi

  local array=($STATUS)
  VERSION=${array[${INDEX}]}
  VERSION=${VERSION%,}  # remove trailing comma, if any
  echo "${COMMAND} -> ${VERSION}"
}

# get the ubuntu version
UBUNTU_REL=`lsb_release -r | cut -c10-`
UBUNTU_NAME=`lsb_release -cs`

SHOWONLY=0
OPTIONAL=0
ENTRY=()
while [[ $# -gt 0 ]]; do
  key="$1"
  case ${key} in
    -s|--show)
      SHOWONLY=1
      shift
      ;;
    -a|--all)
      OPTIONAL=1
      shift
      ;;
    -h|--help)
      echo "This script installs the programs necessary to run the drupal docker containers and"
      echo " additional programs used for development. In most cases it attempts to find the latest"
      echo " version of the program and install it. If the program is already loaded and is the"
      echo " latest version, it will be skipped. If it is an older version, it will ask if you want"
      echo " to upgrade. It also allows you to skip the optional development tools."
      echo
      echo "After this script completes you should be able to run the start_drupal.sh script."
      echo
      echo "The following arguments are optional:"
      echo "  -h  : display this help information"
      echo "  -s  : only show current versions installed - do NOT install any software"
      echo "  -a  : install all optional tools"
      exit 0
      ;;
    *)
      ENTRY+=("$1")
      shift
      ;;
  esac
done

if [ ${SHOWONLY} -eq 1 ]; then
  echo "Ubuntu version is ${UBUNTU_REL}  (${UBUNTU_NAME})"
  get_version "svn" 2
  get_version "docker" 2
  get_version "docker-compose" 2
  get_version "google-chrome" 2
  get_version "mysql-workbench" 4
  STATUS=`which phpstorm`
  if [ "${STATUS}" == "" ]; then
    echo "PHPStorm not installed"
  else
    echo "PHPStorm already installed"
  fi
  exit 0
fi

# make sure ubuntu version is correct
if [ ${UBUNTU_REL} != "18.04" ]; then
  echo "Your Ubuntu version is ${UBUNTU_REL}"
  echo "This script is meant for 18.04, so there may be issues with some commands."
  read -p "Do you wish to continue? (Y/n): " RESPONSE
  if [ "${RESPONSE}" != "Y" ] && [ "${RESPONSE}" != "y" ]; then
    exit 1
  fi
fi

# check if optional programs desired
if [ ${OPTIONAL} -eq 0 ]; then
  echo "This can optionally also install PHPStorm, MySQL Workbench, and Chrome browser."
  read -p "Do you wish to install these? (Y/n): " RESPONSE
  if [ "${RESPONSE}" != "Y" ] && [ "${RESPONSE}" != "y" ] && [ ${SHOWONLY} -eq 0 ]; then
    OPTIONAL=1
  fi
fi

# do an update and load some needed tools
resp=`sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu ${UBUNTU_NAME} stable"`
if [ $? -ne 0 ]; then
  resp=`echo $resp | grep NO_PUBKEY`
  echo
  echo "ERROR: check if the error message indicated there was no public key available"
  read -p "       if so, enter the value following NO_PUBKEY (or press ENTER to exit): " RESPONSE
  if [ "${RESPONSE}" == "" ]; then
    exit 1
  fi
  echo "adding key: ${RESPONSE}"
  sudo apt-key adv --keyserver keyserver.ubuntu.com --recv-keys ${RESPONSE}
  if [ $? -ne 0 ]; then
    echo
    echo "ERROR: There was an error adding the key, sorry"
    exit 1
  fi
fi

sudo apt update &> /dev/null
sudo apt install -y curl jq

# install apache and subversion
get_version "svn" 2
if [ "${VERSION}" == "" ]; then
  echo "------------------------------------"
  echo "- installing apache svn            -"
  echo "------------------------------------"
  sudo apt install -y apache2 subversion libapache2-mod-svn
  sudo mkdir -p /opt/svn
fi

# install latest version of docker
INSTALL=0
get_version "docker" 2
if [ "${VERSION}" == "" ]; then
  INSTALL=1
else
  # get the list of avaliable releases for Ubuntu 18.04 (bionic) (the 1st entry will be the latest)
  AVAILABLE=$(apt-cache madison docker-ce | grep "ubuntu-${UBUNTU_NAME}" | grep "${UBUNTU_NAME}/stable" | cut -d" " -f4)
  array=($AVAILABLE)
  LATESTNAME=${array[0]}
  # now extract just the version portion of the release (eliminate any ':' prepended to it and
  # anything following the first trailing '~'
  LATEST=${LATESTNAME#*:}     # removes the 5: preceeding the version number (if any)
  LATEST=${LATEST%~*}         # removes the ~ubuntu-bionic suffix
  LATEST=${LATEST%~*}         # removes the ~3-0 suffix
  if [ "${VERSION}" != "${LATEST}" ]; then
    read -p "  the latest version is: ${LATEST} - do you want to update? (Y/n): " RESPONSE
    if [ "${RESPONSE}" == "Y" ] || [ "${RESPONSE}" == "y" ]; then
      # stop docker first, if it is running
      sudo systemctl stop docker
      # uninstall old version
      echo "- uninstalling old version"
      sudo apt-get remove docker docker-engine docker.io
      INSTALL=1
    fi
  fi
fi
if [ ${INSTALL} -eq 1 ]; then
  echo "------------------------------------"
  echo "- installing docker                -"
  echo "------------------------------------"
  sudo apt install -y docker.io
  sudo systemctl start docker
  sudo systemctl enable docker
fi

# install latest version of docker-compose
INSTALL=0
get_version "docker-compose" 2
LATEST=$(curl --silent https://api.github.com/repos/docker/compose/releases/latest | jq .name -r)
DESTINATION=/usr/local/bin/docker-compose
if [ "${VERSION}" == "" ]; then
  INSTALL=1
elif [ "${VERSION}" != "${LATEST}" ]; then
  read -p "  the latest version is: ${LATEST} - do you want to update? (Y/n): " RESPONSE
  if [ "${RESPONSE}" == "Y" ] || [ "${RESPONSE}" == "y" ]; then
    # uninstall old version
    echo "- uninstalling old version"
    sudo apt-get remove docker-compose
    sudo rm /usr/local/bin/docker-compose
    INSTALL=1
  fi
fi
if [ ${INSTALL} -eq 1 ]; then
  echo "------------------------------------"
  echo "- installing docker-compose        -"
  echo "------------------------------------"
  sudo curl -L https://github.com/docker/compose/releases/download/${LATEST}/docker-compose-$(uname -s)-$(uname -m) -o $DESTINATION
  sudo chmod +x ${DESTINATION}
fi

# install Google Chrome
get_version "google-chrome" 2
if [ "${VERSION}" == "" ] && [ ${OPTIONAL} -eq 1 ]; then
  echo "------------------------------------"
  echo "- installing Google Chrome         -"
  echo "------------------------------------"
  sudo apt install wget
  wget https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
  sudo dpkg -i google-chrome-stable_current_amd64.deb
fi

# install MySQL Workbench and configure it for the database
get_version "mysql-workbench" 4
if [ "${VERSION}" == "" ] && [ ${OPTIONAL} -eq 1 ]; then
  echo "------------------------------------"
  echo "- installing MySQL Workbench       -"
  echo "------------------------------------"
  sudo apt install -y mysql-workbench
fi

# install PHPStorm
# TODO: don't know how to show PHPStorm version
STATUS=`which phpstorm`
if [ "${STATUS}" == "" ] && [ ${OPTIONAL} -eq 1 ]; then
  echo "------------------------------------"
  echo "- installing PHPStorm              -"
  echo "------------------------------------"
  sudo snap install phpstorm --classic
else
  echo "PHPStorm already installed"
fi

# add user to docker group if needed
STATUS=`groups $USER | grep docker`
if [ "${STATUS}" == "" ]; then
  echo "- adding $USER to 'docker' group"
  sudo usermod -aG docker $USER
  RESTART=1
fi

# add user to www-data group if needed
STATUS=`groups $USER | grep www-data`
if [ "${STATUS}" == "" ]; then
  echo "- adding $USER to 'www-data' group"
  sudo usermod -aG www-data $USER
  RESTART=1
fi

# check if we need to logout and log back in
if [ ${RESTART} -ne 0 ]; then
  echo "You need to reboot (or re-login) for changes to groups to take effect"
  read -p "Do you wish to reboot now? (Y/n): " RESPONSE
  if [ "${RESPONSE}" != "Y" ] && [ ${RESPONSE} != "y" ]; then
    exit 1
  fi
  echo "=== REBOOTING SYSTEM ==="
  sleep 1
  sudo reboot
fi
