#!/bin/bash

# checks
[[ $# != 2 ]] && echo "Usage: $0 <repo> <bundleVersion>" && exit 1

echo PWD is $PWD
git clone $1 && cd "$(basename "$_" .git)"
BUNDLE_VERSION=$1 make -f /Makefile bundle-full
#echo "::set-output name=result::$a"