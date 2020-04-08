#!/bin/bash

# Set this at the top of the file to assert “strict mode” to cause
# the program to terminate immediately on errors.
#
# Unoffical Bash "strict mode"
# http://redsymbol.net/articles/unofficial-bash-strict-mode/
# -e : exit when a non-0 exit code is returned by any command 
# -u : using an unset variable the script will exit with an error 
# -o pipefail : use the 1st unsuccessful code as exit code of pipeline
set -euo pipefail
IFS=$'\t\n' # Stricter IFS settings

#----------------------------------------------------------------------
# To extract the path of a specified file: dirname
# get the path of the program being executed ($0) and
# - set a variable to its parent directory
HOME=`dirname "$0"`/..

#----------------------------------------------------------------------
# To test if a variable has not been set (uninitialized) or is set to NULL:
# NOTE: if the unset variable flag is set, you must unset it before using this.
#   you 'unset' an option strangely enough by using a + instead of - before option in 'set' command.
set +u
# - check if $FLAGS is uninitialized, and if so set it to a default value
if [ -z "$FLAGS" ]; then
  echo "FLAGS is not defined"
  FLAGS="-X"
fi
if [ ! -z "$FLAGS" ]; then
  echo "FLAGS is now defined as: $FLAGS"
fi
FLAGS=""
if [ -z "$FLAGS" ]; then
  echo "This equates to undefining FLAGS, since its value is NULL"
fi
set -u

#----------------------------------------------------------------------
# To extract a word from a string (words can be seperated by one
# or more spaces/tabs):
#
# $1 = string of words with 1st entry being the index selection (N) into rest of string
# returns Nth entry (error if invalid value defined)
function get_selected_word
{
  N=$1
  shift
  STRING=$*
  arr=($STRING)
  echo ${arr[N-1]}
}

# return the 3rd item following numeric selection passed to the function
get_selected_word 3 first second third fourth fifth sixth
# > third
# note that wrapping words in quotes packs them into single "item"
get_selected_word 3 "first second third" fourth fifth sixth
# > fifth

#----------------------------------------------------------------------
# Extract the characters following the first occurrance of a substring
# - prints all chars preceeding the first ':'
VALUE="5:19.03.5~3-0~ubuntu-bionic"
echo ${VALUE#*:}
# > 19.03.5~3-0~ubuntu-bionic

#----------------------------------------------------------------------
# Extract the characters following the last occurrance of a substring
# - prints the last folder of the current path
#VALUE="/home/user/path/filename.txt"  # > filename.txt
VALUE=`pwd`
echo ${VALUE##*/}

#----------------------------------------------------------------------
# Extract the characters preceding the last occurrance of a substring
# - prints the full path of the parent directory of the current folder.
#VALUE="/the/file/name/txt"   # > /the/file/name
VALUE=`pwd`
echo ${VALUE%/*}

#----------------------------------------------------------------------
# Extract the characters preceding the first occurrance of a substring
# - prints all chars (*) followinging the first '.'
VALUE="the.file.name.txt"
echo ${VALUE%%.*}
# > the
