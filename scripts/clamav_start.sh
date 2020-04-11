#!/bin/bash

echo "starting ClamAV service..."
docker exec -ti drupal_www_1 service clamav-daemon start
