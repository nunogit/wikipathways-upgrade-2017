#!/bin/sh -e

(
    export PWD=`pwd`;
    cd conf &&
        find . -type f | xargs -i{} sudo sh -c "cd /etc; rm -f {}; ln -s $PWD/{} {}" ||
            echo No conf directory!
)

sudo a2ensite wikipathways.conf

CURRENT_ENVVARS_PATH="$(readlink -f /etc/apache2/envvars)"
CURRENT_ENVVARS_DIR="$(dirname $CURRENT_ENVVARS_PATH)"
EXPECTED_ENVVARS_PRIVATE_PATH="$CURRENT_ENVVARS_DIR/envvars.private"
if [ -e "$EXPECTED_ENVVARS_PRIVATE_PATH" ]; then
  . "$EXPECTED_ENVVARS_PRIVATE_PATH"
else
  ./create-private-envvars.sh
fi

sudo systemctl restart apache2

# Remove Links temporarily
(cd mediawiki && git reset --hard )

git submodule update --init --recursive
. ./linkify-mediawiki.sh

to_install=""
is_installed() {
	dpkg -l $1 > /dev/null  2>&1
	if [ $? -ne 0 ]; then
		to_install="$1 $to_install"
	fi
}

is_installed php-mbstring
is_installed php-mysql
is_installed php-xml
is_installed php-zip
is_installed composer
is_installed python-pygments

if [ -n "$to_install" ]; then
	echo Installing: $to_install
	sudo apt install $to_install
fi

sudo -i bash "./extensions/GPMLConverter/install"

if [ ! -L /etc/apache2/mods-enabled/headers.load ]; then
	echo enable mod_headers
	sudo a2enmod headers
fi

stdir=`stat -c %a images`
if [ $stdir -ne 1777 ]; then
	echo Making images writable
	chmod 1777 $dir
fi

sudo apt-get autoremove -y

cat > "./.git/hooks/post-checkout" <<EOF
#!/usr/bin/env bash
./update-submodules.sh
EOF
sudo chmod ug+x "./.git/hooks/post-checkout"

cat > "./.git/hooks/post-rewrite" <<EOF
#!/usr/bin/env bash
./update-submodules.sh
EOF
sudo chmod ug+x "./.git/hooks/post-rewrite"
