#!/bin/bash

echo "Select:"
echo "1 = force rebuild of images without cache (clean build)"
echo "2 - remove all containers, volumes, networks and images (cleaning disk space)"
read -p "enter selection: " SELECT
if [ "${SELECT}" == "1" ]; then
  echo "- forcing rebuild"
  docker system prune
  docker-compose build --no-cache
elif [ "${SELECT}" == "2" ]; then
  docker system prune -a
fi
