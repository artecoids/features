#!/usr/bin/env bash
# This is part of devcontainers-contrib script library
# source: https://github.com/devcontainers-contrib/features
set -e

PLUGIN=${PLUGIN:-""}
VERSION=${VERSION:-"latest"}
PLUGINREPO=${PLUGINREPO:-""}

# Clean up
rm -rf /var/lib/apt/lists/*

if [ -z "$PLUGIN" ]; then
	echo -e "'plugin' variable is empty, skipping"
	exit 0
fi

if [ "$(id -u)" -ne 0 ]; then
	echo -e 'Script must be run as
    root. Use sudo, su, or add "USER root" to your Dockerfile before running this script.'
	exit 1
fi

check_alpine_packages() {
    apk add -v --no-cache "$@"
}

check_packages() {
	if ! dpkg -s "$@" >/dev/null 2>&1; then
		if [ "$(find /var/lib/apt/lists/* | wc -l)" = "0" ]; then
			echo "Running apt-get update..."
			apt-get update -y
		fi
		apt-get -y install --no-install-recommends "$@"
	fi
}

updaterc() {
	if cat /etc/os-release | grep "ID_LIKE=.*alpine.*\|ID=.*alpine.*" ; then
		echo "Updating /etc/profile"
		echo -e "$1" >>/etc/profile
	fi
	if [[ "$(cat /etc/bash.bashrc)" != *"$1"* ]]; then
		echo "Updating /etc/bash.bashrc"
		echo -e "$1" >>/etc/bash.bashrc
	fi
	if [ -f "/etc/zsh/zshrc" ] && [[ "$(cat /etc/zsh/zshrc)" != *"$1"* ]]; then
		echo "Updating /etc/zsh/zshrc"
		echo -e "$1" >>/etc/zsh/zshrc
	fi
}

install_via_asdf() {
	PLUGIN=$1
	VERSION=$2
	REPO=$3

	# install git and curl if does not exists
	if cat /etc/os-release | grep "ID_LIKE=.*alpine.*\|ID=.*alpine.*" ; then
        check_alpine_packages curl git ca-certificates
	elif cat /etc/os-release | grep  "ID_LIKE=.*debian.*\|ID=.*debian.*"; then
		check_packages curl git ca-certificates
	fi

	if ! type asdf >/dev/null 2>&1; then
		su - "$_REMOTE_USER" <<EOF
            git clone --depth=1 \
            -c core.eol=lf \
            -c core.autocrlf=false \
            -c fsck.zeroPaddedFilemode=ignore \
            -c fetch.fsck.zeroPaddedFilemode=ignore \
            -c receive.fsck.zeroPaddedFilemode=ignore \
            "https://github.com/asdf-vm/asdf.git" $_REMOTE_USER_HOME/.asdf 2>&1


            if [ ! -f "\${HOME}/.bashrc" ] || [ ! -s "\${HOME}/.bashrc" ] ; then
                cp  /etc/skel/.bashrc "\${HOME}/.bashrc"
            fi
            if  [ ! -f "\${HOME}/.profile" ] || [ ! -s "\${HOME}/.profile" ] ; then
                cp  /etc/skel/.profile "\${HOME}/.profile"
            fi

            . $_REMOTE_USER_HOME/.asdf/asdf.sh

            if asdf list "$PLUGIN" >/dev/null 2>&1; then
                echo "$PLUGIN  already exists - skipping installation"
                exit 0
            fi
			echo PLUGIN="$PLUGIN"
			echo REPO="$REPO"
			sleep 10
            asdf plugin add "$PLUGIN" "$REPO"
            asdf install "$PLUGIN" "$VERSION"
            asdf global "$PLUGIN" "$VERSION"
EOF

		updaterc ". $_REMOTE_USER_HOME/.asdf/asdf.sh"

	fi
}


install_via_asdf "$PLUGIN" "$VERSION" "$PLUGINREPO"
