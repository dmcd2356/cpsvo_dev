# cpsvo_development
The docker files and bash script files used for setting up a Drupal system for running a CPS-VO sandbox for development purposes. This can significantly reduce the installation and configuration effort required for a full software installation and makes it much easier to take a "snapshot" of changes to the database to save and allow you to easily switch between different source code and database versions without affecting the "live" CPS-VO. Changes to the software or database can then be propagated to the SVN version control and production release respectively as needed.
There are two docker containers, one of which contains the Apache web server and PHP installation 'drupal_www_1' and the other contains the MySQL database server 'drupal_db_1'. When installed on an Ubuntu system, they comprise the rest of a LAMP stack.

The host system is assuemd to be Ubuntu 18.04.

The script folder contains the following:

config.sh
  This should be run once on your ubuntu 18.04 system prior to starting the docker containers for drupal. It is meant to load all of the tools necessary to run the Drupal docker containers as well as the development tools needed to test and modify the code.

start-drupal.sh
  This script starts up a pair of docker containers that make up part of a LAMP stack for running Drupal. Following this script's completion, you should then run dbload.sh (if the MySQL has not been setup yet) to load the database into the running instance of MySQL. Following that, you can browse to: 127.0.0.1/admin to then setup the database for your Drupal sandbox and you are ready to go. (optional arguments: -d  forces it to execute in background)

dbload.sh
  This script loads the database file into the running MySQL docker container. It looks in the database subdirectory for .sql files. If none are found it exits; if only one is found, it will load it; if multiple files are found it will prompt the user as to which one to load.

dbdump.sh
  This script dumps the current database into a file (date and time stamped) in the Drupal development path.

copyimages.sh
  This script copies the images files from the Drupal development images folder to the running Drupal code path. The docker containers must be running.

svncheckout.sh
  This script checks out the latest CPS-VO codebase files from SVN into the src subfolder of the Drupal development path.

certificate.sh
  This script creates a self-signed (snake-oil) certificate in the certificates subfolder of the Drupal development path.

clamav_start.sh
  This will start the ClamAV anti-virus daemon in the drupal_www_1 container. This is used by Drupal and gives a status report warning if it is not running.

clean.sh
  This can do either of 2 things:
  1) clear out saved data in the docker projects and do a clean build (without using cached data) so the project truly builds from scratch
  2) removes all images, containers, network connections, and volumes to clear out disk space.

