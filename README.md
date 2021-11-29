# seqflow merge
Seqflow Merge automates feature propagation to release branches defined by [seqflow](https://github.com/greg-chuchro/seqflow).

## Get Started
```
name: seqflow-merge

on:
  push:
    branches:
      - main

concurrency: seqflow-merge

jobs:
  seqflow-merge:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v2
      with:
        fetch-depth: 2
    - uses: actions/setup-dotnet@v1
    - uses: greg-chuchro/seqflow-merge@v0.0.1
      with:
        callback: |
          echo v$NEW_RELEASE_VERSION
````
