#!/bin/bash

# taken from https://github.com/TeslaGov/shell-semver/blob/master/semver/increment_version.sh (MIT license)

# Increment a version string using Semantic Versioning (SemVer) terminology.

# Parse command line options.

while getopts ":Mmp" Option
do
  case $Option in
    M ) major=true;;
    m ) minor=true;;
    p ) patch=true;;
  esac
done

shift $(($OPTIND - 1))

begins_with_v=false
original_version=$1

# Check if tag begins with 'v'
if [[ $original_version == v* ]] ;
then
    begins_with_v=true
    version=$(echo -n $original_version | cut -d'v' -f 2)
else
    version=$original_version
fi


# Build array from version string.

a=( ${version//./ } )

# If version string is missing or has the wrong number of members, show usage message.

if [ ${#a[@]} -ne 3 ]
then
  echo "usage: $(basename $0) [-Mmp] major.minor.patch"
  exit 1
fi

# Increment version numbers as requested.

if [ ! -z $major ]
then
  ((a[0]++))
  a[1]=0
  a[2]=0
fi

if [ ! -z $minor ]
then
  ((a[1]++))
  a[2]=0
fi

if [ ! -z $patch ]
then
  ((a[2]++))
fi

if [ "$begins_with_v" = true ] ;
then
    echo "v${a[0]}.${a[1]}.${a[2]}"
else
    echo "${a[0]}.${a[1]}.${a[2]}"
fi


