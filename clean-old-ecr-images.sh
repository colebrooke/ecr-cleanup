#!/bin/bash

# Script to clean ECR repos

## Usage:
## ./clean-old-ecr-images.sh <IMAGE-REPO-NAME> <WEEKS-TO-KEEP>
##
## Non-interactive, for running in cron or your C.I.:
## echo "y" | ./clean-old-ecr-images.sh <IMAGE-REPO-NAME> <WEEKS-TO-KEEP>

## Dependencies
## Requires jq and aws command line
## aws credentials are also needed to access the repo. These can be set up using the "aws configure" command.

# delete_images myrepo 8
# will delete images older than 8 weeks
function delete_images {
  REPO=$1
  WEEKS=${2:-16}

  SECONDS=$(echo "$WEEKS * 604800" | bc)
  WEEKS_AGO=$(echo "$(date +%s)-$SECONDS" | bc)

  IMAGES=$(aws ecr describe-images --repository-name $REPO --output json | jq '.[]' | jq '.[]' | jq "select (.imagePushedAt < $WEEKS_AGO)" | jq -r '.imageDigest')

  while IFS= read -r IMAGE; do
    if [ "$IMAGE" != "" ]; then
      echo "Deleting $IMAGE from $REPO"
      aws  ecr batch-delete-image --repository-name $REPO --image-ids imageDigest=$IMAGE
    fi
  done <<< "$IMAGES"
}

# delete_images_all_repos 12
# will delete images in all repositories older than 12 weeks
function delete_images_all_repos {
  REPOSITORIES=$(aws ecr describe-repositories --output json | jq -r '.[]|.[].repositoryName')

  while IFS= read -r REPO; do
    echo "processing ECR repository $REPO"
    delete_images $REPO $1
  done <<< "$REPOSITORIES"
}
