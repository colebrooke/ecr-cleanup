#!/bin/bash

# Script to clean images with no tag from ECR repos

# Usage:
# ./clean-untagged-ecr-images.sh <IMAGE-REPO-NAME>

# Dependencies
# Requires jq and aws command line
# aws credentials are also needed to access the repo. These can be set up using the "aws configure" command.

# Check if jq is available
type jq >/dev/null 2>&1 || { echo >&2 "The jq utility is required for this scipt to run."; exit 3; }

# Check if aws cli is available
type aws >/dev/null 2>&1 || { echo >&2 "The aws cli is required for this script to run."; exit 3; }

REPO=$1

IMAGES=$(aws ecr list-images --repository-name $REPO --query 'imageIds[?type(imageTag)!=`string`].[imageDigest]' --output text)

read -p "Delete all images with no tag from $REPO (y/n)? " CHOICE
case "$CHOICE" in 
  y|Y ) 
    for DIGEST in ${IMAGES[*]}; do
      aws ecr batch-delete-image --repository-name $REPO --image-ids imageDigest=$DIGEST
    done
  ;;
  * ) exit 0 ;;
esac


