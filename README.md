# cpsvo_development
The docker files and bash script files used for setting up a Drupal system for running a CPS-VO sandbox for development purposes. This can significantly reduce the installation and configuration effort required for a full software installation and makes it much easier to take a "snapshot" of changes to the database to save and allow you to easily switch between different source code and database versions without affecting the "live" CPS-VO. Changes to the software or database can then be propagated to the SVN version control and production release respectively as needed.
There are two docker containers, one of which contains the Apache web server and PHP installation 'drupal_www_1' and the other contains the MySQL database server 'drupal_db_1'. When installed on an Ubuntu system, they comprise the rest of a LAMP stack.

The host system is assumed to be Ubuntu 18.04.
