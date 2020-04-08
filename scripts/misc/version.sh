#!/bin/bash

function check_for_version
{
  RETVAL=0 # indicate failure by default
  
  local string=$1
  local numcount=0
  local dpcount=0
  local mode=0 # indicate we must start with numeric
  for (( i=0; i<${#string}; i++ )); do
#    echo "${string:$i:1}"
    if [[ ${string:$i:1} =~ [0-9] ]]; then
      if [ ${mode} -eq 0 ]; then
        numcount=$((numcount+1))
      fi
      mode=1
    elif [[ ${string:$i:1} == "." ]]; then
      if [ ${mode} -eq 1 ]; then
        dpcount=$((dpcount+1))
      else
        # can't have 2 dec pts in a row or begin with a dec pt
        return 0
      fi
      mode=0
    else
      # invalid character in entry
      return 0
    fi
  done
  # verify we have a combination of numbers and decpts
  # (and must have 1 more numeric group than dec pts to begin and end with one)
  if [ ${dpcount} -gt 0 ] && [ ${numcount} -gt ${dpcount} ]; then
    RETVAL=1
  fi
}

if [ $# -eq 0 ]; then
  read -p "enter command to check for: " COMMAND
else
  COMMAND=$1
fi

STATUS=`${COMMAND} --version 2> /dev/null`
ERROR=$?
#echo "${STATUS}"
if [ ${ERROR} -ne 0 ]; then
  echo "- Command '${COMMAND}' returned error ${ERROR}"
  exit 1
fi
if [ "${STATUS}" == "" ]; then
  echo "- Command '${COMMAND}' was not found"
  exit 1
fi

array=($STATUS)

# this is for the commands that play nice and are formatted as: <command> ["version"] Version_num",
# where <command> is the same as the command you entered (perhaps in different case).
NAME=${array[0]}  # 1st entry should be the command name
NAME=${NAME%,}  # remove trailing comma, if any
shopt -s nocasematch
if [[ "${NAME}" == "${COMMAND}" ]]; then
  # specify which element (starting at 0) in which to fing version number
  VERSION=${array[1]}
  if [[ "${VERSION}" == "version" ]]; then
    # if "version" is the 2nd entry, let's assume the next value is the version number
    VERSION=${array[2]}
    VERSION=${VERSION%,}  # remove trailing comma, if any
    RETVAL=1
  else
    # otherwise, let's see if it looks like a version number
    VERSION=${VERSION%,}  # remove trailing comma, if any
    check_for_version ${VERSION}
  fi

  if [ ${RETVAL} -eq 1 ]; then
    echo "${COMMAND} Version: ${VERSION}"
    exit 0
  fi
fi

# in some cases (e.g. mysql-workbench and google-chrome) the response is hard to figure because
# the name becomes obfuscated - google-chrome becomes "Google Chrome" and worse, mysql-workbench
# becomes "MySQL Workbench CE (GPL)". So for these cases, we simply look for the first entry
# that resembles a version: munerics interspersed with decimal points.
# Note: this currently excludes non-numeric characters in the version.
length=${#array[@]}
for index in ${!array[@]}; do
  entry=${array[${index}]}
  entry=${entry%,}  # remove trailing comma, if any
  check_for_version ${entry}
  if [ ${RETVAL} -eq 1 ]; then
    echo "${COMMAND} Version: ${entry}"
    exit 0
  fi
done

# just can't figure it out...
echo "- Command ${COMMAND} does not return version number"
exit 1
