#!/bin/bash

# Run this script as root to configure a *fresh* DigitalOcean Ubuntu 22.04
# server. This script did work at least once to set up the server, so hopefully
# it'll help you when you need it. This should be run from within a clone of
# this repo. You can run each of the sub-scripts individually if you need to.
#
# (I'm running very low on caffeine, trying to get this show on the road. May
# the sun look upon you favourably and this script bring you caffeine.)
#
# - Aleksa Sarai, 2024.

set -Eeuxo pipefail

curdir="$(dirname "${BASH_SOURCE[0]}")"
scriptsdir="$curdir/setup.d"

# shellcheck source=./setup.d/.helpers.bash
source "$scriptsdir/.helpers.bash"

# Make sure you set these variables!
check_slack_auth

# Run all the scripts by default.
for file in "$scriptsdir"/*.sh
do
	echo "-- running $(basename "$file") --" >&2
	"$file"
done
