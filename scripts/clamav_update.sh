#!/bin/bash

echo "updating ClamAV database..."
# daemon
docker exec -ti drupal_www_1 service clamav-freshclam stop
docker exec -ti drupal_www_1 freshclam
docker exec -ti drupal_www_1 service clamav-freshclam start
