#!/bin/bash

# Script to clean ECR repos

# Usage:
# ./clean-old-ecr-images.sh <IMAGE-REPO-NAME>

# Dependencies
# Requires jq and aws command line
# aws credentials are also needed to access the repo. These can be set up using the "aws configure" command.

# Check if jq is available
type jq >/dev/null 2>&1 || { echo >&2 "The jq utility is required for this scipt to run."; exit 3; }

# Check if aws cli is available
type aws >/dev/null 2>&1 || { echo >&2 "The aws cli is required for this script to run."; exit 3; }

REPO=$1

read -p "Delete images older than 3 weeks from $REPO (y/n)? " CHOICE

case "$CHOICE" in
  y|Y)
    THREE_WEEKS_AGO=$(echo "$(date +%s)-1814400" | bc)
    echo "epoch $THREE_WEEKS_AGO"
    IMAGES=$(aws ecr describe-images --repository-name $REPO --output json | jq '.[]' | jq '.[]' | jq "select (.imagePushedAt < $THREE_WEEKS_AGO)" | jq -r '.imageDigest')
    for IMAGE in ${IMAGES[*]}; do
      aws ecr batch-delete-image --repository-name $REPO --image-ids imageDigest=$IMAGE
    done
  ;;

  *) exit 0  ;;
esac


