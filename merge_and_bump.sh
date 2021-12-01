#!/bin/bash

set +e
git cherry-pick $MAIN_BRANCH_NAME
MERGE_RESULT=$?
set -e
if [ $MERGE_RESULT -ne 0 ]; then
    git cherry-pick --abort
else
    set +e
    dotnet test --configuration Release -p:ContinuousIntegrationBuild=true
    TEST_RESULT=$?
    set -e
    if [ $TEST_RESULT -eq 0 ]; then
        BASE_VERSION=$(sed -n 's/.*<Version>\(.*\)<\/Version>.*/\1/p' $(find . -name *.csproj | grep --invert-match Test))
        BASE_MAJOR_VERSION=$(echo "$BASE_VERSION" | sed -n 's/\([0-9]*\).*/\1/p')
        BASE_MINOR_VERSION=$(echo "$BASE_VERSION" | sed -n 's/[0-9]*\.\([0-9]*\).*/\1/p')
        BASE_PATCH_VERSION=$(echo "$BASE_VERSION" | sed -n 's/[0-9]*\.[0-9]*\.\([0-9]*\)/\1/p')
        NEW_RELEASE_VERSION=$BASE_MAJOR_VERSION.$BASE_MINOR_VERSION.$(($BASE_PATCH_VERSION + 1))
        sed -i "s/<Version>.*<\/Version>/<Version>$NEW_RELEASE_VERSION<\/Version>/" $(find . -name *.csproj | grep --invert-match Test)
        git add $(find . -name *.csproj | grep --invert-match Test)
        git commit --amend --no-edit
        git push origin $BRANCH_NAME
        eval "$SEQFLOW_MERGE_CALLBACK"
    fi
fi
