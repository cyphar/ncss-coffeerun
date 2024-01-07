#!/bin/bash

DOMAIN="${DOMAIN:-caffeine.syd.ncss.life}"
HOST_PORT="${HOST_PORT:-8000}"

function warn() {
	echo "warn: $*" >&2
}

function bail() {
	echo "error: $*" >&2
	exit 1
}

function check_slack_auth() {
	SLACK_OAUTH_CLIENT_ID="${SLACK_OAUTH_CLIENT_ID:-}"
	SLACK_OAUTH_CLIENT_SECRET="${SLACK_OAUTH_CLIENT_SECRET:-}"
	if [[ -z "$SLACK_OAUTH_CLIENT_ID" ]] || [[ -z "$SLACK_OAUTH_CLIENT_SECRET" ]]
	then
		bail "you need to provide SLACK_OAUTH_CLIENT_ID and SLACK_OAUTH_CLIENT_SECRET"
	fi
}
