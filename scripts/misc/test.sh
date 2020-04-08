#!/bin/bash

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
  echo "IPADDR = ${IPADDR}"
else
  echo "IPADDR = 127.0.0.1"
fi
echo "------------------------"
exit 0

AVAILABLE=$(apt-cache madison docker-ce | grep "ubuntu-bionic" | grep "bionic/stable" | cut -d" " -f4)
array=($AVAILABLE)
LATESTNAME=${array[0]}
echo ${LATESTNAME}
LATEST=${LATESTNAME#*:}
echo ${LATEST}
LATEST=${LATEST%~*}
echo ${LATEST}
LATEST=${LATEST%~*}
echo ${LATEST}
exit 0

get_version "curl" 1
get_version "jq" 0

get_version "svn" 2
get_version "docker" 2
get_version "docker-compose" 2
get_version "google-chrome" 2
get_version "mysql-workbench" 4
#get_version "phpstorm" 2
