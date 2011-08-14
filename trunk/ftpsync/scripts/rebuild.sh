#!/bin/sh
#
# $Id$
#
# rebuilds target/ftpsync-1.x.tar.bz2
#

PROJECTDIR=$(cd $(dirname $0)/.. ; pwd)
cd $PROJECTDIR

rm -rf target/ftpsync*
mkdir -pv target

FSVER=$(/usr/share/pba-cbs/sh/get_deb_version.sh .)
echo "Building FTPSync.pl $FSVER"

COLLECTDIR="target/ftpsync-$FSVER"
mkdir -pv $COLLECTDIR
cp -avu \
  src/ftpsync.pl \
  doc/*.txt \
  debian/changelog
  $COLLECTDIR/

cd $COLLECTDIR/..
tar -cjvf ftpsync-$FSVER.tar.bz2 ftpsync-$FSVER
rm -rf $COLLECTDIR

echo "Built target/ftpsync-$FSVER.tar.bz2"

