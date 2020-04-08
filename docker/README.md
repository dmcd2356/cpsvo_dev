#### This folder contains the following files:

**docker-compose.yml**

  This is that main docker-compose file that describes the 2 docker services (each in their own container) to create: **www** for Apache web server and PHP and **db** for the MySQL database server. The database setup is completely defined in this file and the Apache/PHP setup uses *Dockerfile* to do its configuration.

**Dockerfile**

  This contains the configuration for generating the **www** container consisting of Apache web server and PHP.

**htaccess_patch.ini**

  This contains the patch information to add to the .htaccess file in the drupal base directory. It contains any configuration changes in PHP needed for running the CPS-VO.

**clamd.conf**

  This contains a modified version of the clamd.conf file contained in the /etc/clamav directory in the **www** container for running ClamAV anti-virus. The change enables using localhost TCP port 3310 instead of the unix socket for communication.
