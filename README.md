# CPS-VO Development Files
This project consists of the docker and bash script files used for setting up a Drupal system that can run a CPS-VO sandbox for development purposes. This can significantly reduce the installation and configuration effort required for a full software installation and makes it easy to try out modifications and be able to easily restore your original setup when your changes are no longer needed. The scripts require that you have access to the vodev repository for the codebase and that you have a corresponding database dump that corresponds to the same version of codebase. When you make changes you would like to save, you can use SVN to add the codebase changes to a branch in version control and can use the scripts to take a "snapshot" of changes to the database. To restore these to your sandbox you simply pull in the codebase version you want and use another script to load the database. This allows you to easily switch between different source code and database versions in your sandbox without affecting the "live" CPS-VO. Desired changes to the codebase can then be propagated to the main branch with SVN and database changes to the production release as needed.

There are two docker containers that run the LAMP stack, one of which contains the *Apache web server* and *PHP* installation called **drupal_www_1** and the other contains the *MySQL database server* called **drupal_db_1**. When installed on an Ubuntu system, they comprise the rest of a LAMP stack.

The host system is assumed to be Ubuntu 18.04.

The scripts are generally used in the following way:

- The first time you are setting up your Ubuntu system for running the docker images, you should run the **config.sh** script. This will install all of the required software on your host system. The main components that are necessary for running are *docker* and *docker-compose* for creating the containers and *svn* version control for acessing the CPS-VO codebase repo. However, since this is for development purposes, it also installs other development tools: *MySQL Workbench* for database management, *PHPStorm* for viewing, modifying and comitting changes into version control, and *Google Chrome* for interfacing with Drupal. It attempts to install the latest versions of each required program.

- To startup the docker containers and perform some configuration chores, you then run **start-drupal.sh**. If you currently don't have the CPS-VO codebase pulled in, it will run SVN to pull in the latest checked in release. If you have already pulled in a version and have made code changes, it will not change anything. It also will create a self-signed certificate for running https if you do not already have one. Since it is self-signed, your browser will probably give you a warning about it, but you can ignore it because you created the certificate and it is only running on localhost. When the script completes, the 2 containers should be actively running. If you are running without the **-d** option, you can see the commands as they run and can easily check if there are any errors. You can also terminate the containers safely just typing a *ctrl-C*. If you use the **-d** to run the process in the background, you can use *docker-compose stop* to terminate the containers.

- Following the startup of the docker containers, you will need to add your database files if you have not run the containers before or if you want to revert to a different database. The database is placed in a persistent volume in docker, so it will remain intact after shutting down and restarting the containers. To load the database, run **dbload.sh**. You must have at least 1 *(.sql)* file in the *database* folder of the path you placed this repo in. If there is more than 1 file, the script will prompt you for a choice. This process takes a few minutes, so be patient.

- If you had any user images that needed to be copied, they should be placed in the *images/users* or *images/themes-redux* folders of the path you placed this repo in. If they were prior to running the *start-drupal* script, that script already copied them to the drupal directories. Otherwise, you may place them in the appropriate directory and can run the **copyimages.sh** script to place them there now.

- Because it generally doesn't startup properly in the *Dockerfile* when running *start-drupal.sh* you should also run **clamav-start.sh** after it completes. This is the virus protection daemon that is used by Drupal.

- If this is the first time running the docker containers, when you startup the web browser to access Drupal, it will give an error that you will need to change the flag value for **$update_free_access** from *FALSE* to *TRUE* in the file *drupal/drupal/sites/default/settings.php* so that it can perform an update. Then when the update completes, you will need to change this value back to *FALSE*.

- At this point, you should be able to run the web browser (Firefox or Chrome) and point it to: https://127.0.0.1/admin to access the Drupal interface. If this is the first time you have run the docker containers or have changed database files since the last time you ran, a Drupal page should be displayed indicating the database needs configuring, so it will first prompt for the language selection and then the database info. Make sure to click on the 'Advanced' selection to open the selections for the MySQL Host location. The settings should be set to the following (as specified in the *docker-compose.yml* file):

  - *Database name:*     **vsfs_db**
  - *Database username:* **vsfsuser**
  - *Database password:* **vsfspass**
  - *Advanced -> Host:*  **127.0.0.1**
  - *Advanced -> Port:*  **3306**

When complete, it will indicate a database is already installed, select view existing database.

If you get an error that indicates you may have the wrong database name or password, check the *drupal/drupal/sites/default/settings.php* file and look for the **$db_url** definition. It should be set to:

  $db_url = 'mysqli://vsfsuser:vsfspass@localhost/vsfs_db';

- Once it seems to be running, you might want to visit https://127.0.0.1/admin/reports/status that will give you an idea of any other issues you may need to correct. You can ignore the *Unsupported release* error under the *Module and theme update status* entry. There will probably also be a warning that *cron* hasn't run in a long time, but you can fix that by clicking in the link to manually run cron.

- If you have made changes to database that you can't seem to get rid of and you just want to start everything over fresh, run the **clean.sh** script. This will give you the selection of either re-running the containers without using any cache data (a clean build), or blow away all containers, volumes (including database) etc and starting over completely.
