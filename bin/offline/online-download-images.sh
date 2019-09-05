#!/usr/bin/env bash

# There are two bash scripts at work here:
# the main script (the one you're reading) needs internet and does two things:
# 1. pull and save multiple docker images from the internet and save them as tar files
# 2. write another bash script
#
# The offline script can then, along with the docker tar files, be copied to an environment without internet
# It then allows loading the docker images from the tar files into your environment,
# and pushing them to a local docker registry that can work disconnected from the internet.
# See also ansible/registry.yml for details on that setup.
#
# Usage: 1. edit version numbers in this script
#        2. run this script
#        3. follow the instructions printed at the end

set -ex

#####################################################
# PLEASE UPDATE VERSIONS BELOW!
#####################################################

BACKEND_VERSION=2.60.0
WEBAPP_VERSION="42720-0.1.0-64e6cb-v0.22.0-production"
TEAM_VERSION="10562-2.8.0-9e1e59-v0.22.1-production"
ACCOUNT_VERSION="242-2.0.1-c4282e-v0.20.4-production"

###########################################################
# You should not need to change the code below
############################################################

# prepare destination folder
NOW=$(date +"%Y-%m-%d_%H-%M-%S")
FOLDER="update-$NOW"
LOAD_SCRIPT="$FOLDER/load_into_registry.sh"
mkdir "$FOLDER"

# now that versions are known, write load_into_registry script
echo "#!/usr/bin/env bash

set -ex

for image in *.tar; do
    docker load < \"\$image\"
done

PREFIX=wire
REGISTRY=quay.io

function load() {
    local NAME=\$1
    local VERSION=\$2
    img=\"\$PREFIX/\$NAME:\$VERSION\"
    docker tag \"\$REGISTRY/\$img\" \"localhost/\$img\"
    docker push \"localhost/\$img\"
}

" > "$LOAD_SCRIPT"
chmod +x "$LOAD_SCRIPT"

function download() {
    local NAME=$1
    local VERSION=$2
    docker pull "quay.io/wire/$NAME:$VERSION"
    docker save "quay.io/wire/$NAME:$VERSION" > "$FOLDER/$NAME-$VERSION.tar"
    echo "load $NAME $VERSION" >> "$LOAD_SCRIPT"
}

images=( brig galley gundeck cannon proxy spar cargohold nginz nginz_disco galley-schema gundeck-schema brig-schema spar-schema stern )
for image in "${images[@]}"; do
    download "$image" "$BACKEND_VERSION"
done

download webapp "$WEBAPP_VERSION"
download account "$ACCOUNT_VERSION"

# requires authentication!
download team-settings "$TEAM_VERSION"

set +x

echo "Done downloading docker images."
echo "You now have a folder $FOLDER"
echo "You can transfer that folder, or optionally create a tar file first that you then transfer, e.g."
echo "  tar -czvf $FOLDER.tgz $FOLDER"
echo ""
echo "On the target machine:"
echo "1. (optionally:) uncompress using:   tar -xzvf $FOLDER.tgz"
echo "2. cd $FOLDER"
echo "3. ./$(basename "$LOAD_SCRIPT")"
