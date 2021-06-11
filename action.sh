#!/bin/bash

MAIN_BRANCH_NAME=$(git branch --show-current)
COMMITS_COUNT=$(git rev-list --count $MAIN_BRANCH_NAME)
if [ $COMMITS_COUNT -eq 1 ]; then
    git switch --create v0.0
    git push origin v0.0
    exit
fi

CURRENT_VERSION=$(sed -n 's/.*<Version>\(.*\)<\/Version>.*/\1/p' $(find . -name *.csproj | grep --invert-match Test))
CURRENT_MAJOR_VERSION=$(echo "$CURRENT_VERSION" | sed -n 's/\([0-9]*\).*/\1/p')
CURRENT_MINOR_VERSION=$(echo "$CURRENT_VERSION" | sed -n 's/[0-9]*\.\([0-9]*\).*/\1/p')
CURRENT_PATCH_VERSION=$(echo "$CURRENT_VERSION" | sed -n 's/[0-9]*\.[0-9]*\.\([0-9]*\)/\1/p')

NEW_DLL=$(dotnet build $(find . -name *.csproj | grep --invert-match Test) --configuration Release | sed -n 's/.*\s[^/]*\(\/.*dll\).*/\1/p')
cp $NEW_DLL $TEMP_DIR
NEW_DLL="$TEMP_DIR"/$(basename "$NEW_DLL")
git reset --hard HEAD~1
CURRENT_DLL=$(dotnet build $(find . -name *.csproj | grep --invert-match Test) --configuration Release | sed -n 's/.*\s[^/]*\(\/.*dll\).*/\1/p')
git reset --hard HEAD@{1}

dotnet tool install --global Ghbvft6.Synver --version 0.3.*
VERSIONING_TOOL_OUTPUT=$(synver $NEW_DLL $CURRENT_DLL)
NEW_VERSION=$(echo "$VERSIONING_TOOL_OUTPUT" | sed -n 's/\([0-9]*\.[0-9]*\.[0-9]*\).*/\1/p')
NEW_MAJOR_VERSION=$(echo "$NEW_VERSION" | sed -n 's/\([0-9]*\).*/\1/p')
NEW_MINOR_VERSION=$(echo "$NEW_VERSION" | sed -n 's/[0-9]*\.\([0-9]*\).*/\1/p')
NEW_PATCH_VERSION=$(echo "$NEW_VERSION" | sed -n 's/[0-9]*\.[0-9]*\.\([0-9]*\)/\1/p')
if [ "$NEW_VERSION" != "$CURRENT_VERSION" ]; then
    if [ $NEW_PATCH_VERSION -ne $CURRENT_PATCH_VERSION ]; then
        SEQFLOW_CALLBACK=$(<$GITHUB_ACTION_PATH/merge.sh)
        curl -sL https://raw.githubusercontent.com/greg-chuchro/seqflow/v0.0.1/action.sh > $GITHUB_ACTION_PATH/seqflow.sh
        . $GITHUB_ACTION_PATH/seqflow.sh
    elif [ $NEW_MINOR_VERSION -ne $CURRENT_MINOR_VERSION ]; then
        set +e
        GIT_USER_NAME=$(git config --global user.name)
        GIT_USER_EMAIL=$(git config --global user.email)
        set -e
        git config --global user.name "seqflow-action"
        git config --global user.email ""
        git config remote.origin.fetch "+refs/heads/*:refs/remotes/origin/*"
        git fetch
        
        LATEST_BRANCH_FULL_NAME=$(git branch --remotes --list origin/v[0-9]*.[0-9]* --sort -version:refname | head -n 1 | xargs)
        LATEST_BRANCH_NAME=${LATEST_BRANCH_FULL_NAME#"origin/"}
        LATEST_BRANCH_MAJOR_VERSION=$(echo $LATEST_BRANCH_NAME | sed -n 's/v\([0-9]*\).*/\1/p')
        LATEST_BRANCH_MINOR_VERSION=$(echo $LATEST_BRANCH_NAME | sed -n 's/v[0-9]*\.\([0-9]*\).*/\1/p')
        INITIAL_PATCH_VERSION=0
        NEW_RELEASE_VERSION=$LATEST_BRANCH_MAJOR_VERSION.$(($LATEST_BRANCH_MINOR_VERSION + 1)).$INITIAL_PATCH_VERSION
        MINOR_BRANCH_NAME=v$LATEST_BRANCH_MAJOR_VERSION.$(($LATEST_BRANCH_MINOR_VERSION + 1))
        git switch --create $MINOR_BRANCH_NAME
        sed -i "s/<Version>.*<\/Version>/<Version>$NEW_RELEASE_VERSION<\/Version>/" $(find . -name *.csproj | grep --invert-match Test)
        git add $(find . -name *.csproj | grep --invert-match Test)
        git commit --amend --no-edit
        git push origin $MINOR_BRANCH_NAME
        eval "$SEQFLOW_MERGE_CALLBACK"

        git switch $MAIN_BRANCH_NAME
        git config --global user.name "$GIT_USER_NAME"
        git config --global user.email "$GIT_USER_EMAIL"
    fi
fi
