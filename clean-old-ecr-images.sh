#!/bin/bash

# Script to clean ECR repos

## Usage:
## ./clean-old-ecr-images.sh <IMAGE-REPO-NAME> <SINCE-TO-KEEP>>
##
## Non-interactive, for running in cron or your C.I.:
## echo "y" | ./clean-old-ecr-images.sh <IMAGE-REPO-NAME> <SINCE-TO-KEEP>

## Dependencies
## Requires jq and aws command line
## aws credentials are also needed to access the repo. These can be set up using the "aws configure" command.
## Set the region in the parameters below.

REGION="eu-north-1"

MERGE_MANIFEST_TYPE="application/vnd.docker.distribution.manifest.list.v2+json"

function get_old_images_sha256 {
  local DATE_FROM_KEEP=$1
  local AWS_RAW_JSON=$2

  # Buildkit only tags merged manifest, that's why firstly delete merged manifests and then arch specific images.
  echo "$(
    echo "$AWS_RAW_JSON" | 
    jq -r --arg time "$DATE_FROM_KEEP" \
          --arg type "$MERGE_MANIFEST_TYPE" \
          '.[] | [.[] | select(.imagePushedAt <= $time)] | sort_by(.imageManifestMediaType != $type) | .[].imageDigest')"
}

function substract_date_unit_from_time {
  local DATE_UNIT=$1
  local CURRENT_DATE=$2
  local CONVERT_TO_SEC=0

  case "${DATE_UNIT: -1}" in
    d|D) CONVERT_TO_SEC=86400    ;;
    w|W) CONVERT_TO_SEC=604800   ;;
    m|M) CONVERT_TO_SEC=2592000  ;;
    y|Y) CONVERT_TO_SEC=31536000 ;;
    *)
      echo "Use the suffix to specify which date to save the images from (day, week, month, year), for example, 1d 3w 5m 3y."
      exit 1
    ;;
  esac

  DATE_UNIT=${DATE_UNIT:0:-1}

  NEW_DATE=$(date -d @$(echo "$CURRENT_DATE - $DATE_UNIT * $CONVERT_TO_SEC" | bc) +"%Y-%m-%dT00:00:00+00:00") || exit 1
  echo "$NEW_DATE"
}

if [ $# -eq 0 ]; then
  # This is small hack to run tests from another file.
  # When we call explicitly this script we get error, because return is not permit.
  # When we call some function above from another file, we just skip futher code and jump into function. 
  { 
    return
  } &> /dev/null
fi

# Check if jq is available
type jq >/dev/null 2>&1 || { echo >&2 "The jq utility is required for this script to run."; exit 1; }

# Check if aws cli is available
type aws >/dev/null 2>&1 || { echo >&2 "The aws cli is required for this script to run."; exit 1; }

# Check number of arguments parsed
if [ $# -ne 2 ]; then
  echo "Usage ./clean-old-ecr-images.sh <IMAGE-REPO-NAME> <SINCE-TO-KEEP> <REGION (OPTIONAL)>"
  exit 1
fi

REPOSITORY=$1
SINCE_TO_KEEP=$2

CURRENT_DATE=$(date +%s)
DATE_TO_KEEP=$(substract_date_unit_from_time $SINCE_TO_KEEP $CURRENT_DATE)

if [ $? -ne 0 ]; then
  if [ -n "$DATE_TO_KEEP" ]; then echo "$DATE_TO_KEEP"; fi
  exit 1
fi

read -p "Delete images older than $DATE_TO_KEEP from $REPOSITORY (y/n)? " CHOICE

case "$CHOICE" in
  y|Y)
    REPOSITORY_DESCRIBE=$(aws ecr describe-images --repository-name $REPO --output json --region $REGION --no-cli-pager)
    IMAGES=$(get_old_images_sha256 $DATE_TO_KEEP "$REPOSITORY_DESCRIBE")
    for IMAGE in ${IMAGES[*]}; do
      echo "Deleting $IMAGE"
      aws ecr batch-delete-image --repository-name $REPOSITORY --image-ids imageDigest=$IMAGE --region $REGION --no-cli-pager
    done
  ;;

  *) exit 0  ;;
esac
echo "Finished."
