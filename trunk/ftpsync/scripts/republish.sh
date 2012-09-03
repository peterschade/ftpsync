#!/bin/sh
#
# $Id$
#
# lets rebuild target/ftpsync-1.x.tar.bz2 and deploys it
# as ftpsync-1.x.tar.bz2 and ftpsync-latest.tar.bz2
#

MYDIR=$( dirname $( readlink -f $( which $0 ) ) )
cd $MYDIR/..

scripts/rebuild.sh || exit 1

FSVER=$(/usr/share/pba-cbs/sh/get_deb_version.sh $PROJECTDIR)
FSTBZ="target/ftpsync-$FSVER.tar.bz2"
echo "Publishing FTPSync.pl $FSVER aka $FSTBZ"

echo "cp-ing to clazzes.org AKA https://download.clazzes.org/ftpsync/"
chmod 0755 $FSTBZ
scp $FSTBZ ftpsync@clazzes.org:/var/www/htdocs/download.clazzes.org/ftpsync/

rm -rf target/ftpsync*

