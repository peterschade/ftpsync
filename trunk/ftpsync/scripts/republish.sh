#!/bin/sh
#
# $Id$
#
# lets rebuild target/ftpsync-1.x.tar.bz2 and deploys it
# as ftpsync-1.x.tar.bz2 and ftpsync-latest.tar.bz2
#

PROJECTDIR=$(cd $(dirname $0)/.. ; pwd)
cd $PROJECTDIR

scripts/rebuild.sh || exit 1

FSVER=$(cat src/ftpsync.pl |grep 'print "FTPSync.pl ' |awk '{print $3}')
FSTBZ="target/ftpsync-$FSVER.tar.bz2"
echo "Publishing FTPSync.pl $FSVER aka $FSTBZ"

echo "cp-ing to clazzes.org AKA https://download.clazzes.org/ftpsync/"
chmod 0755 $FSTBZ
scp $FSTBZ ftpsync@clazzes.org:/var/www/htdocs/download.clazzes.org/ftpsync/

