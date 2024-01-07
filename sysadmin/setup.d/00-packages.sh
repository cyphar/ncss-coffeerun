#!/bin/bash

set -Eeuxo pipefail

curdir="$(dirname "${BASH_SOURCE[0]}")"
#rootdir="$curdir/../.."

# shellcheck source=./.helpers.bash
source "$curdir/.helpers.bash"

# Set up the hierarchy.
mkdir -p /srv/{data,wkd,run}

# * nginx for reverse-proxy.
# * certbot for TLS certs (much security, very wow).
# * Docker to run the thing.
apt update
apt upgrade -y
apt install -y docker.io nginx certbot mosh
