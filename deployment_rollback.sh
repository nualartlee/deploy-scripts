#!/usr/bin/env bash

#
# Rollback To Previous Version
#
# Pulls and deploys the previous version of the current branch from remote origin.
#

# Work from projects's directory
cd "${0%/*}/.."

# Import common functions
source deploy-scripts/common.sh

# Assume the project's name is the same as the containing directory
projectname=${PWD##*/}

# Print header
echo "====================================="
echo "      Revert $projectname"
echo

# Check user is root
check_errs $EUID "This script must be run as root"

# Get the owner of the project
projectowner=$(ls -ld $PWD | awk '{print $3}')

# Determine previous version sudo -u $projectowner git hash
previous=$(sudo -u $projectowner git log --format=%H | sed -n 2p)
check_errs $? "Unable to determine previous git version hash"

# Rollback to previous version
sudo -u $projectowner git reset $previous
check_errs $? "Unable to git-reset previous version from repository"

# Stash current changes
sudo -u $projectowner git stash
check_errs $? "Unable to stash changes in repository"

# Deploy previous version
deploy-scripts/deploy.sh
check_errs $? "Rollback deployment failed."

echo
echo "Rollback Completed"
echo

# Completed successfully
echo
echo "Project Running"
echo
echo
