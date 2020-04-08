#!/bin/bash

# finds the index offset of a substring within a string
#
# #1 = the string in which to search
# $2 = the substring to searchy for
#
# Returns -1 if substring not found, else the offset from start os string
#
function strindex
{ 
  x="${1%%$2*}"
  [[ "$x" = "$1" ]] && echo -1 || echo "${#x}"
}

# pads a string to the right to extend the length to the specified amount
#
# $1 = the desired total length of string
# $2 = the string to pad
#
function pad_right
{
#  size=${#1}
#  padlen=`expr $2 - $size`
  local length=$1
  shift 1
  NEWSTRING="$@                                        "
  NEWSTRING=${NEWSTRING:0:$length}
  echo "$NEWSTRING"
}

# check if user passed in the name of the container. if not, prompt him for it.
if [ $# -eq 0 ]; then
#  echo "Must specify the name of the container to get PID & IPADDR of"
#  echo " or ACTIVE to show PID & IPADDR of all running processes"
#  echo " or ALL    to additionally show STATUS of all other processes"
#  read -p "container name: " CONTAINER
#  if [ "${CONTAINER}" == "" ]; then  exit 0;  fi
  CONTAINER="ACTIVE"
else
  CONTAINER=$@
fi

MULTI=0
if [ "${CONTAINER}" == "ACTIVE" ] || [ "${CONTAINER}" == "ALL" ]; then
  MULTI=1
fi

# if running all of them, loop thru each container found
OFFSET_NAME=-1
OFFSET_STAT=-1
while read -r INPUTLINE; do
  if [ "${INPUTLINE:0:9}" == "CONTAINER" ]; then
    # find offsets for container name and status
    OFFSET_NAME=`strindex "${INPUTLINE}" "NAMES"`
    OFFSET_STAT=`strindex "${INPUTLINE}" "STATUS"`
    if [ ${OFFSET_NAME} -lt 0 ] || [ ${OFFSET_STAT} -lt 0 ]; then
      echo "Could not find NAMES or STATUS in 1st line of 'docker ps' command"
      exit 1
    fi
  else
    # check if we found the specified entry or are doing all of them
    NAME=${INPUTLINE:${OFFSET_NAME}}
    STATUS=`echo ${INPUTLINE:${OFFSET_STAT}} | cut -d ' ' -f1`
    if [ ${NAME} == ${CONTAINER} ] || [ ${MULTI} -eq 1 ]; then
      # display the PID and IPADDR of each entry
      if [ "${STATUS}" == "Up" ]; then
        PID=`exec docker inspect --format '{{ .State.Pid }}' "$NAME"`
        IPADDR=`docker inspect --format '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' $NAME`
        field1=`pad_right 20 "${NAME}"`
        field2=`pad_right 15 "PID = ${PID}"`
        field3="IPADDR = ${IPADDR}"
        echo "${field1}${field2}${field3}"
      elif [ "${CONTAINER}" != "ACTIVE" ]; then
        field1=`pad_right 20 "${NAME}"`
        field2="STATUS = ${STATUS}"
        echo "${field1}${field2}"
      fi
      # if we are not doing all of them, we can exit since we found the entry
      if [ ${MULTI} -eq 0 ]; then
        exit 0
      fi
    fi
  fi
done < <(docker ps -a)

# else, container not found
if [ ${MULTI} -eq 0 ]; then
  echo "Container '${NAME}' not found"
  exit 1
fi
