#!/bin/sh
#
# $Id$
#
# rebuilds target/ftpsync-1.x.tar.bz2
#

PROJECTDIR=$(cd $(dirname $0)/.. ; pwd)
cd $PROJECTDIR

mkdir -pv target
rm -rf target/ftpsync*

FSVER=$(cat src/ftpsync.pl |grep 'print "FTPSync.pl ' |awk '{print $3}')
echo "Building FTPSync.pl $FSVER"

COLLECTDIR="target/ftpsync-$FSVER"
mkdir -pv $COLLECTDIR
cp -avu \
  src/ftpsync.pl \
  doc/COPYING \
  doc/Changes \
  doc/TODO \
  doc/README \
  $COLLECTDIR/

cd $COLLECTDIR/..
tar -cjvf ftpsync-$FSVER.tar.bz2 ftpsync-$FSVER
rm -rf $COLLECTDIR

echo "Built target/ftpsync-$FSVER.tar.bz2"

