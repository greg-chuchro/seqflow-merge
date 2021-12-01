#!/bin/bash

MAIN_BRANCH_NAME=$(git branch --show-current)
COMMITS_COUNT=$(git rev-list --count $MAIN_BRANCH_NAME)
if [ $COMMITS_COUNT -eq 1 ]; then
    exit
fi

PROJECT_FILE=$(find . -name *.*proj | grep --invert-match Test)

BASE_VERSION=$(sed -n 's/.*<Version>\(.*\)<\/Version>.*/\1/p' "$PROJECT_FILE")
BASE_MAJOR_VERSION=$(echo "$BASE_VERSION" | sed -n 's/\([0-9]*\).*/\1/p')
BASE_MINOR_VERSION=$(echo "$BASE_VERSION" | sed -n 's/[0-9]*\.\([0-9]*\).*/\1/p')
BASE_PATCH_VERSION=$(echo "$BASE_VERSION" | sed -n 's/[0-9]*\.[0-9]*\.\([0-9]*\)/\1/p')

ASSEMBLY_NAME=$(sed -n 's/.*<AssemblyName>\(.*\)<\/AssemblyName>.*/\1/p' "$PROJECT_FILE")
if [ "$ASSEMBLY_NAME" == "" ]; then
    PROJECT_FILE_NAME=$(basename "$PROJECT_FILE")
    ASSEMBLY_NAME=${PROJECT_FILE_NAME%.*}
fi
dotnet publish "$PROJECT_FILE" --configuration Release -p:ContinuousIntegrationBuild=true
PUBLISH_FOLDER=$(find . -name publish)
MODIFIED_DLL=$(realpath "$PUBLISH_FOLDER/$ASSEMBLY_NAME.dll")

git config remote.origin.fetch "+refs/heads/*:refs/remotes/origin/*"
git fetch
if [ "$(git branch --remotes --list origin/v[0-9]*.[0-9]*)" == "" ]; then
    MINOR_BRANCH_NAME=v$BASE_MAJOR_VERSION.$BASE_MINOR_VERSION
    git switch --create $MINOR_BRANCH_NAME
    git push origin $MINOR_BRANCH_NAME
    eval "$SEQFLOW_MERGE_CALLBACK"

    git switch $MAIN_BRANCH_NAME
    exit
fi

mv "$PUBLISH_FOLDER" "$TEMP_DIR/latest_publish"
MODIFIED_DLL="$TEMP_DIR/latest_publish"/$(basename "$MODIFIED_DLL")
git reset --hard HEAD~1
dotnet publish "$PROJECT_FILE" --configuration Release -p:ContinuousIntegrationBuild=true
PUBLISH_FOLDER=$(find . -name publish)
BASE_DLL=$(realpath "$PUBLISH_FOLDER/$ASSEMBLY_NAME.dll")
git reset --hard HEAD@{1}

dotnet tool install --global Ghbvft6.Synver --version 0.3.*
set +e
VERSIONING_TOOL_OUTPUT=$(synver $BASE_DLL $MODIFIED_DLL)
SYNVER_RESULT=$?
echo "$VERSIONING_TOOL_OUTPUT"
if [ $SYNVER_RESULT -ne 0 ]; then
    exit $SYNVER_RESULT
fi
set -e

NEW_VERSION=$(echo "$VERSIONING_TOOL_OUTPUT" | sed -n 's/\([0-9]*\.[0-9]*\.[0-9]*\).*/\1/p')
NEW_MAJOR_VERSION=$(echo "$NEW_VERSION" | sed -n 's/\([0-9]*\).*/\1/p')
NEW_MINOR_VERSION=$(echo "$NEW_VERSION" | sed -n 's/[0-9]*\.\([0-9]*\).*/\1/p')
NEW_PATCH_VERSION=$(echo "$NEW_VERSION" | sed -n 's/[0-9]*\.[0-9]*\.\([0-9]*\)/\1/p')

if [ "$NEW_VERSION" == "$BASE_VERSION" ]; then
    SEQFLOW_CALLBACK=$(<$GITHUB_ACTION_PATH/merge.sh)
    curl -sL https://raw.githubusercontent.com/greg-chuchro/seqflow/v0.0.1/action.sh > $GITHUB_ACTION_PATH/seqflow.sh
    . $GITHUB_ACTION_PATH/seqflow.sh
elif [ $NEW_PATCH_VERSION -ne $BASE_PATCH_VERSION ]; then
    SEQFLOW_CALLBACK=$(<$GITHUB_ACTION_PATH/merge_and_bump.sh)
    curl -sL https://raw.githubusercontent.com/greg-chuchro/seqflow/v0.0.1/action.sh > $GITHUB_ACTION_PATH/seqflow.sh
    . $GITHUB_ACTION_PATH/seqflow.sh
elif [ $NEW_MINOR_VERSION -ne $BASE_MINOR_VERSION ]; then
    set +e
    GIT_USER_NAME=$(git config --global user.name)
    GIT_USER_EMAIL=$(git config --global user.email)
    set -e
    git config --global user.name "seqflow-action"
    git config --global user.email ""
    
    LATEST_BRANCH_FULL_NAME=$(git branch --remotes --list origin/v[0-9]*.[0-9]* --sort -version:refname | head -n 1 | xargs)
    LATEST_BRANCH_NAME=${LATEST_BRANCH_FULL_NAME#"origin/"}
    LATEST_BRANCH_MAJOR_VERSION=$(echo $LATEST_BRANCH_NAME | sed -n 's/v\([0-9]*\).*/\1/p')
    LATEST_BRANCH_MINOR_VERSION=$(echo $LATEST_BRANCH_NAME | sed -n 's/v[0-9]*\.\([0-9]*\).*/\1/p')
    INITIAL_PATCH_VERSION=0
    NEW_RELEASE_VERSION=$LATEST_BRANCH_MAJOR_VERSION.$(($LATEST_BRANCH_MINOR_VERSION + 1)).$INITIAL_PATCH_VERSION
    MINOR_BRANCH_NAME=v$LATEST_BRANCH_MAJOR_VERSION.$(($LATEST_BRANCH_MINOR_VERSION + 1))
    git switch --create $MINOR_BRANCH_NAME
    sed -i "s/<Version>.*<\/Version>/<Version>$NEW_RELEASE_VERSION<\/Version>/" $PROJECT_FILE
    git add $PROJECT_FILE
    git commit --amend --no-edit
    git push origin $MINOR_BRANCH_NAME
    eval "$SEQFLOW_MERGE_CALLBACK"

    git switch $MAIN_BRANCH_NAME
    git config --global user.name "$GIT_USER_NAME"
    git config --global user.email "$GIT_USER_EMAIL"
fi
