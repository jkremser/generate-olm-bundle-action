#!/bin/bash

# checks
[[ $# != 2 ]] && echo "Usage: $0 <repo> <bundleVersion>" && exit 1
_REPO=$1
_BUNDLE_VERSION=$2

echo PWD is $PWD
git clone ${_REPO} && cd "$(basename "$_" .git)"
BUNDLE_VERSION=${_BUNDLE_VERSION} make -f /Makefile bundle-full

echo -e "\n\n\n\nDone. Here is the result:\n=========================\n\n"
tree ./bundle
#echo "::set-output name=result::$a"