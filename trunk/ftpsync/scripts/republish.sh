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

if [ ! -d public_html ]
then
  mkdir -pv public_html
  echo "Synching from cw01 AKA http://ossw.ibcl.at/FTPSync"
  xsync root@cw01.ibcl.at:/var/www/htdocs/w3ibcl/ossw.ibcl.at/FTPSync public_html
else
  echo "Using local public_html as master"
fi

FSVER=$(cat src/ftpsync.pl |grep 'print "FTPSync.pl ' |awk '{print $3}')
FSTBZ="target/ftpsync-$FSVER.tar.bz2"
echo "Publishing FTPSync.pl $FSVER aka $FSTBZ"
cp -uva $FSTBZ public_html/
cp -uva $FSTBZ public_html/ftpsync-latest.tar.bz2
cp -uva site/*.html public_html

echo "Synching to cw01 AKA http://ossw.ibcl.at/FTPSync"
xsync public_html root@cw01.ibcl.at:/var/www/htdocs/w3ibcl/ossw.ibcl.at/FTPSync
ssh root@cw01.ibcl.at cpacls -R /var/www/htdocs/w3ibcl/ossw.ibcl.at /var/www/htdocs/w3ibcl/ossw.ibcl.at/FTPSync

echo "Synching to sourceforge AKA http://ftpsync.sourceforge.net/"
test -f tmp/.sfpw && cat tmp/.sfpw 
xsync public_html ibcl@ftpsync.sourceforge.net:/home/groups/f/ft/ftpsync/htdocs/
ssh ibcl@ftpsync.sourceforge.net chmod -R ugo+rx /home/groups/f/ft/ftpsync/htdocs/*

# rsync -avP -e ssh pub/ftpsync-1.2.34.tar.bz2 ibcl@frs.sourceforge.net:uploads/


