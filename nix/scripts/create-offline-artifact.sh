#!/usr/bin/env bash

mkdir -p assets assets/containers-{helm,other,system} assets/debs assets/binaries

mirror-apt-bionic assets/debs
mirror-apt-jammy assets/debs



