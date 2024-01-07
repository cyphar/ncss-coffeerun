#!/bin/bash

set -Eeuxo pipefail

curdir="$(dirname "${BASH_SOURCE[0]}")"
rootdir="$curdir/../.."

# shellcheck source=./.helpers.bash
source "$curdir/.helpers.bash"

# We need the slack oauth stuff for this.
check_slack_auth

# Make sure the *actual* Docker service starts. Socket activation will cause
# lots of heartache.
systemctl start docker.service
systemctl enable docker.service

# Build our image.
image="ncss/coffeebot:$DOMAIN.$(date +"%Y%m%d.%s")"
docker build -t "$image" "$rootdir"

# short hand for docker run bunch-of-args
# usage: drun $image $command...
function drun() {
	docker run \
		-v /srv/data:/srv/data \
		-e DATABASE_URL="sqlite:///$dbfile" \
		-e SLACK_OAUTH_CLIENT_ID="$SLACK_OAUTH_CLIENT_ID" \
		-e SLACK_OAUTH_CLIENT_SECRET="$SLACK_OAUTH_CLIENT_SECRET" \
		"$@"
}

# Create the database.
dbfile="/srv/data/coffeerun-prod.db"
# Make sure coffeebot can access the db dir.
chown -R 5000:5000 "$(dirname "$dbfile")"
if [ -e "$dbfile" ]
then
	warn "database $dbfile already exists -- skipping drop tables!"
else
	drun --rm \
		"$image" python ./create_db.py
fi

# Start the container, with an eternal restart policy.
#drun -d --restart=always \
drun --restart=always \
	-p "127.0.0.1:$HOST_PORT:8000/tcp" \
	"$image"
