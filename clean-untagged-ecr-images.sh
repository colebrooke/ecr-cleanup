#!/bin/bash

# Script to clean images with no tag from ECR repos

# Usage:
# ./clean-untagged-ecr-images.sh <IMAGE-REPO-NAME>

REPO=$1

IMAGES=$(aws ecr list-images --repository-name $REPO --query 'imageIds[?type(imageTag)!=`string`].[imageDigest]' --output text)

read -p "Delete all images with no tag from $REPO (y/n)? " CHOICE
case "$CHOICE" in 
  y|Y ) 
    for DIGEST in ${IMAGES[*]}; do
      aws ecr batch-delete-image --repository-name $REPO --image-ids imageDigest=$DIGEST
    done
  ;;

  n|N ) echo "Skipping $REPO" && exit 0;;
  * ) echo "invalid";;
esac


