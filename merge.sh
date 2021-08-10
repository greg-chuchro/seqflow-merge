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
        git push origin $BRANCH_NAME
    fi
fi
