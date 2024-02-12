#!/bin/bash

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
NORMAL='\033[0m'

# Statuses
FAILED="${RED}Failed${NORMAL}"
SUCCESS="${GREEN}Success${NORMAL}"

# Import functions
source ./clean-old-ecr-images.sh

# Test time converter
TEST_DATE="2023-12-16T00:00:00+00:00"

function test_date_substruct {
    DATE_UNIT=$1
    DATE=$(date -d $2 +%s)
    EXPECTED=$3

    ACTUAL=$(substract_date_unit_from_time $DATE_UNIT $DATE)
    if [ "$ACTUAL" != "$EXPECTED" ]; then
        echo -e "$FAILED: ACTUAL=$ACTUAL != EXPECTED=$EXPECTED"
        return 1
    fi
}

test_date_substruct   "1d" $TEST_DATE "2023-12-15T00:00:00+00:00" || exit 1
test_date_substruct   "0d" $TEST_DATE "2023-12-16T00:00:00+00:00" || exit 1
test_date_substruct  "39d" $TEST_DATE "2023-11-07T00:00:00+00:00" || exit 1
test_date_substruct "370d" $TEST_DATE "2022-12-11T00:00:00+00:00" || exit 1
test_date_substruct   "3w" $TEST_DATE "2023-11-25T00:00:00+00:00" || exit 1
test_date_substruct   "7w" $TEST_DATE "2023-10-28T00:00:00+00:00" || exit 1
test_date_substruct   "1m" $TEST_DATE "2023-11-16T00:00:00+00:00" || exit 1
test_date_substruct   "3m" $TEST_DATE "2023-09-17T00:00:00+00:00" || exit 1
test_date_substruct   "1y" $TEST_DATE "2022-12-16T00:00:00+00:00" || exit 1
test_date_substruct   "2y" $TEST_DATE "2021-12-16T00:00:00+00:00" || exit 1
test_date_substruct  "10y" $TEST_DATE "2013-12-18T00:00:00+00:00" || exit 1

echo -e "$SUCCESS: test to time converter"

# Test data selector. 
# You can change DATE_TO_KEEP and write extra JSON objects into test_describe_images.json.
TEST_JSON=$(cat test_describe_images.json)
DATE_TO_KEEP="2023-12-16T00:00:00+00:00"
IMAGES=$(get_old_images_sha256 $DATE_TO_KEEP "$TEST_JSON")

FIRSTLY_MERGED_MANIFESTS="true"
DATE_TO_KEEP_UNIX=$(date -d $DATE_TO_KEEP '+%s')
for IMAGE in ${IMAGES[*]}; do
    IMAGE_INFO=$(echo "$TEST_JSON" | jq --arg sha256 "$IMAGE" '.[] | .[] | select(.imageDigest == $sha256)')

    IMAGE_DATE_UNIX=$(date -d "$(echo "$IMAGE_INFO" | jq -r '.imagePushedAt')" +%s)

    if [ $IMAGE_DATE_UNIX -gt $DATE_TO_KEEP_UNIX ]; then
        echo -e "$FAILED: get image that out of time range"
        exit 1
    fi

    if [ $(echo "$IMAGE_INFO" | jq -r '.imageManifestMediaType') = "$MERGE_MANIFEST_TYPE" ]; then
        if [ "$FIRSTLY_MERGED_MANIFESTS" = "false" ]; then
            echo -e "$FAILED: merge manifest do not go firstry"
            exit 1
        fi
    else
        FIRSTLY_MERGED_MANIFESTS="false"
    fi
done

echo -e "$SUCCESS: test to get images in delete time range"
echo -e "$SUCCESS: test to get firstly merged manifests"
