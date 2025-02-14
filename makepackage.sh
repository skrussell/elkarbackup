#!/bin/bash
#
# @copyright 2012-2021 Binovo IT Human Project, S.L.
# @license http://www.opensource.org/licenses/bsd-license.php New-BSD
#

#
# prepare source for build
#

if [ "$(which composer)" == "" ]
then
    echo "Download and install composer"
    curl -s https://getcomposer.org/installer | php
    ln -s composer.phar composer
    export PATH=$PATH:$PWD
fi
composer install --no-interaction

if [ -d .debian ]; then
    rm -fR .debian
fi
mkdir .debian
cp -a debian/* .debian
mkdir -p .debian/usr/share/elkarbackup
cp -a * .debian/usr/share/elkarbackup

# remove unneeded files from copy to package
find .debian -type f -name "*.deb"| xargs rm -rf
find .debian/usr/share/elkarbackup/public/js/dojo-release-1.8.1 -name "*.uncompressed.js"|xargs rm -f
find .debian -name ".git*" -o -name "*~" -o -name "*#*"| xargs rm -rf
rm -rf .debian/usr/share/elkarbackup/var/{cache,log,sessions} .debian/usr/share/elkarbackup/backups .debian/usr/share/elkarbackup/debian
# fix or delete some files so that lintian doesn't complain (so much)
rm -fR .debian/usr/share/elkarbackup/vendor/twbs/bootstrap/docs/
rm -fR .debian/usr/share/elkarbackup/vendor/twbs/bootstrap/test-infra/
find .debian -name "*.png" -o -name "*.gif" -o -name "*.php" -o -name "README" -o -name "*.md" -o -name "*.dist" -o -name "*.ini" -o -name "*.yml" -o -name "*.rst" -o -name "*.xml" -o -name "*.js"| xargs chmod a-x
find .debian/usr/share/elkarbackup/public/js/dojo-release-1.8.1 -type f|xargs chmod a-x
# setup cache, session and log directories in var
mkdir -p .debian/var/cache/elkarbackup
mkdir -p .debian/var/log/elkarbackup
mkdir -p .debian/var/log/elkarbackup/jobs
mkdir -p .debian/var/lib/elkarbackup/sessions
mkdir -p .debian/usr/share/elkarbackup/var/
ln -s /var/cache/elkarbackup        .debian/usr/share/elkarbackup/var/cache
ln -s /var/log/elkarbackup          .debian/usr/share/elkarbackup/var/log
ln -s /var/lib/elkarbackup/sessions .debian/usr/share/elkarbackup/var/sessions
# setup configuration in /etc
mkdir -p .debian/etc/elkarbackup/
cp .debian/usr/share/elkarbackup/config/parameters.yaml.dist .debian/etc/elkarbackup/parameters.yaml
rm .debian/usr/share/elkarbackup/config/parameters.yaml
ln -s /etc/elkarbackup/parameters.yaml .debian/usr/share/elkarbackup/config/parameters.yaml
mv .debian/env.local.php .debian/usr/share/elkarbackup/.env.local.php
# put copyright notices and changelog in its place
mkdir -p .debian/usr/share/doc/elkarbackup
# Copy changelog and copyright files
cp -a CHANGELOG.md .debian/usr/share/doc/elkarbackup/CHANGELOG.md
mv .debian/changelog .debian/usr/share/doc/elkarbackup/changelog.Debian
cp -a debian/DEBIAN/copyright .debian/usr/share/doc/elkarbackup
gzip -f --best .debian/usr/share/doc/elkarbackup/changelog.Debian
# ensure directory permissions are right
find .debian -type d | xargs -I {} chmod 755 "{}"
# ensure config files have the right permissions
chmod 0440 .debian/etc/sudoers.d/elkarbackup
chmod 0644 .debian/DEBIAN/conffiles .debian/DEBIAN/templates .debian/etc/cron.d/elkarbackup 
chmod 0755 .debian/DEBIAN/config .debian/DEBIAN/postinst .debian/DEBIAN/postrm .debian/DEBIAN/preinst

# use prod environment in console by default
sed -i "s#'dev'#'prod'#"                                                   .debian/usr/share/elkarbackup/bin/console
chmod a+x .debian/usr/share/elkarbackup/bin/console
VERSION=$(cat debian/DEBIAN/control | grep 'Version' | sed -e 's/Version: //' -e 's/ *//')
mkdir -p .debian/var/spool/elkarbackup/backups
mkdir -p .debian/var/spool/elkarbackup/uploads
# clean up /usr/share/elkarbackup
pushd .debian/usr/share/elkarbackup
ls | egrep -v 'bin|config|extra|migrations|public|src|templates|translations|var|vendor'|xargs rm -rf
popd
# Symfony 3.4 wants composer.json for detecting project directory
cp -a composer.json .debian/usr/share/elkarbackup

#
# build an verify
#
fakeroot dpkg-deb --build .debian elkarbackup_${VERSION}_all.deb
if [ $? -ne 0 ]; then
    echo "Error building package."
    exit 1
fi
echo Package created

lintian elkarbackup_${VERSION}_all.deb | tee lintian.log | egrep '^E'
