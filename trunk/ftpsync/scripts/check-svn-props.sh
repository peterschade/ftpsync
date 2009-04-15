#!/bin/sh

#
# This script checks some per-file svn properties
#
# e.g. the Id tag:
#
# $Id$
#
# This script can also be used to check other things on all source files.
#
# Warnings:
# Do not forget to run ant's clean task before running this script!
# This script needs about a minute to run, this is ok.
#

PROJECTDIR=$(cd $(dirname $0)/.. ; pwd)
cd $PROJECTDIR

FINDBASE=.

# we now can be sure to be in .../ibclweb

FEXTLIST="htm html pl sh txt xml"
#FEXTLIST="txt"
for FEXT in $FEXTLIST
do
  find $FINDBASE -name "*.$FEXT" \
    |grep -v "\/\.svn\/" \
    |grep -v "\/bin\/" \
    |grep -v "\/dist\/" \
    |grep -v "\/javadoc" \
    |grep -v "\/target" \
    |while read FN 
    do
      svn propget svn:keywords "$FN" |grep Id >/dev/null || svn propset svn:keywords "Id" "$FN"
    done
done

