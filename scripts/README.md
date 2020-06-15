#### This folder contains the following files:

**config.sh**

  This should be run once on your Ubuntu 18.04 system prior to starting the docker containers for drupal. It is meant to load all of the tools necessary to run the Drupal docker containers as well as the development tools needed to test and modify the code.

**start-drupal.sh**

  This script starts up a pair of docker containers that make up part of a LAMP stack for running Drupal. Following this script's completion, you should then run dbload.sh (if the MySQL has not been setup yet) to load the database into the running instance of MySQL. Following that, you can browse to: 127.0.0.1/admin to then setup the database for your Drupal sandbox and you are ready to go. _(optional arguments: **-d** forces it to execute in background)_

**dbload.sh**

  This script loads the database file into the running MySQL docker container. It looks in the database subdirectory for .sql files. If none are found it exits; if only one is found, it will load it; if multiple files are found it will prompt the user as to which one to load.

**dbdump.sh**

  This script dumps the current database from your sandbox into a file (date stamped) in the Drupal development path.

**dbprod.sh**

  This script dumps the current database from the production VO into a file (date stamped) in the Drupal development path.

**copyimages.sh**

  This script copies the images files from the Drupal development images folder to the running Drupal code path. The docker containers must be running.

**svncheckout.sh**

  This script checks out the latest CPS-VO codebase files from SVN into the src subfolder of the Drupal development path.

**certificate.sh**

  This script creates a self-signed (snake-oil) certificate in the certificates subfolder of the Drupal development path.

**clamav_start.sh**

  This will start the ClamAV anti-virus daemon in the drupal_www_1 container. This is used by Drupal and gives a status report warning if it is not running.

**email_config.sh**

  This will configure ssmtp for working with GMail for Drupal mail redirection. The mail redirection currently does not work, but this gets it close.

**clean.sh**

  This can do either of 2 things:
  1) clear out saved data in the docker projects and do a clean build (without using cached data) so the project truly builds from scratch
  2) removes all images, containers, network connections, and volumes to clear out disk space.

