#!/bin/bash

set +e
git cherry-pick $MAIN_BRANCH_NAME
MERGE_RESULT=$?
set -e
if [ $MERGE_RESULT -ne 0 ]; then
    git cherry-pick --abort
else
    set +e
    dotnet test
    TEST_RESULT=$?
    set -e
    if [ $TEST_RESULT -eq 0 ]; then
        CURRENT_VERSION=$(sed -n 's/.*<Version>\(.*\)<\/Version>.*/\1/p' $(find . -name *.csproj | grep --invert-match Test))
        CURRENT_MAJOR_VERSION=$(echo "$CURRENT_VERSION" | sed -n 's/\([0-9]*\).*/\1/p')
        CURRENT_MINOR_VERSION=$(echo "$CURRENT_VERSION" | sed -n 's/[0-9]*\.\([0-9]*\).*/\1/p')
        CURRENT_PATCH_VERSION=$(echo "$CURRENT_VERSION" | sed -n 's/[0-9]*\.[0-9]*\.\([0-9]*\)/\1/p')
        NEW_RELEASE_VERSION=$CURRENT_MAJOR_VERSION.$CURRENT_MINOR_VERSION.$(($CURRENT_PATCH_VERSION + 1))
        sed -i "s/<Version>.*<\/Version>/<Version>$NEW_RELEASE_VERSION<\/Version>/" $(find . -name *.csproj | grep --invert-match Test)
        git add $(find . -name *.csproj | grep --invert-match Test)
        git commit --amend --no-edit
        git push origin $BRANCH_NAME
        eval "$SEQFLOW_MERGE_CALLBACK"
    fi
fi
