#!/usr/bin/env bash

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
