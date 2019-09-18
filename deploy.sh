#!/usr/bin/env bash

#
# Project Deployment Script
#
# Pulls the latest version of the current from remote origin.
# Creates docker containers, passwords, keys, etc
#
# Append -dev to the containing directory to use docker-compose-dev.yml file
# Otherwise the default docker-compose.yml will be used
#
# The project should already be present under git with remote origin
# set up before running this script
#
# Custom scripts/build.sh and scripts/post_build.sh scripts will be run
# if found

# Work from projects's directory
cd "${0%/*}/.."

# Import common functions
source deploy-scripts/common.sh

# Assume the project's name is the same as the containing directory
projectname=${PWD##*/}

# Set deployment type according to directory name tag
if [[ "$projectname" =~ ^.*-dev$ ]]
then
  type=Development
else
  type=Production
fi

# Print header
clear
echo "=============================================================="
echo "  $projectname $type Deployment"
echo

# Set docker-compose file
dockerfile=docker-compose.yml
if [[ "$type" == "Development" ]]
then
  if [ -e docker-compose-dev.yml ]
  then
    dockerfile=docker-compose-dev.yml
  else
    echo "docker-compose-dev.yml file not found, using default"
    echo
  fi
fi

# Check user is root
check_errs $EUID "This script must be run as root"

# Get the owner of the project
projectowner=$(ls -ld $PWD | awk '{print $3}')

# Check if required packages are installed
echo "Checking required packages"
check_package docker
check_package docker-compose
echo

# Pull latest version from remote origin
sudo -u $projectowner git pull
check_errs $? "Unable to pull from remote repository"

# Pull latest submodules' versions from remote origins
sudo -u $projectowner git pull --recurse-submodules origin master
check_errs $? "Unable to pull submodules from remote repositories"

# Run any custom build script
if [ -e scripts/build.sh ]
then
    echo "Running custom build script"
    scripts/build.sh
    check_errs $? "Custom build script failed"

else
    echo "No custom build scripts"
fi

# Ensure docker is running
service docker start
check_errs $? "Failed starting docker"

# Stop containers
docker-compose down
check_errs $? "Failed stopping containers"

# Rebuild containers
echo
echo "Building containers"
docker-compose -f $dockerfile build
check_errs $? "Failed building containers"

# Run containers in background
echo
echo "Starting containers"
docker-compose -f $dockerfile up -d
check_errs $? "Failed starting containers"

# Allow for startup
echo
echo "Startup delay..."
sleep 5

# Check that no container exited with errors
echo
echo "Checking container status"
if docker-compose -f $dockerfile ps | egrep -q 'Exit [^0]'; then
  check_errs 1 "Containers exited with errors"
fi

# Run any custom post_build script
if [ -e scripts/post_build.sh ]
then
    echo "Running custom post_build script"
    scripts/post_build.sh
    check_errs $? "Custom post_build script failed"

else
    echo "No custom post_build scripts"
fi

echo
echo "Deployment Completed"
echo

# Run tests
echo "Starting tests..."
deploy-scripts/deployment_test.sh
check_errs $? "Test failed."

# Completed successfully
echo
echo "Project Running"
echo
echo
