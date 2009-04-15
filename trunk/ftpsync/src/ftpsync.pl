#!/usr/bin/perl
#
# ftpsync.pl
# 
# See attached README file for any details, or call 
# ftpsync.pl -h
# for quick start.
#
# LICENSE
#
#    FTPSync.pl (ftpsync) is free software; you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation; either version 2 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program; if not, write to the Free Software
#    Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
#
# FTPSync.pl (ftpsync) is also eMail-Ware, which means that the initial author 
# would like to get an eMail, 
# - if anyone uses the script on production level,
# - if anyone distributes or advertises it in any way,
# - if anyone starts to (try to) improve it.
#
#
################################################################################

#
# Options etc.
#
use File::Find;
use Net::FTP;
use strict;

# Option Variables
# meta
my $returncode=0;
my $configfile="~/.ftpsync";
# basics
my $localdir="";
my $remoteURL="";
my $syncdirection="put";
my $ftpuser="";
my $ftppasswd="";
my $ftpserver="";
my $ftpdir="";
# verbosity
my $doverbose=1;
my $dodebug=0;
my $doquiet=0;
my $doinfoonly=0;

# cfg file given on command line?
my $curopt;
for $curopt (@ARGV) {
  if ($curopt =~ /^cfg=/) {
    $configfile=$'; 
    if (! -r $configfile) { print "Config file does not exist: " . $configfile . "\n"; $returncode+=1; }
  }
}

# Config File
# [...]

# Other Command Line Parameters
for $curopt (@ARGV) {
  if ($curopt =~ /^-[a-zA-Z]/) {
    my $i;
    for ($i=1; $i<length($curopt); $i++) {
      my $curoptchar=substr($curopt,$i,1);
      if    ($curoptchar =~ /[dD]/)  { $dodebug=1; $doverbose=1; $doquiet=0; }
      elsif ($curoptchar =~ /[gG]/)  { $syncdirection="get"; }
      elsif ($curoptchar =~ /[hH]/)  { print_syntax(); exit 0; }
      elsif ($curoptchar =~ /[iI]/)  { $doinfoonly=1; }
      elsif ($curoptchar =~ /[pP]/)  { $syncdirection="put"; }
      elsif ($curoptchar =~ /[qQ]/)  { $dodebug=0; $doverbose=0; $doquiet=1; }
      elsif ($curoptchar =~ /[vV]/)  { $doverbose=1; }
      else  { print "ERROR: Unknown option: \"-" . $curoptchar . "\"\n"; $returncode+=1; }
    }
  }
  elsif ($curopt =~ /^cfg=/) { next; }
  elsif ($curopt =~ /^ftp:\/\/([^@\/\\\:]+):([^@\/\\\:]+)@([a-zA-Z01-9\.]+)\/(.+)/) {
    $remoteURL = $curopt;
    if ($localdir eq "") { $syncdirection="get"; }
  }
  else {
    if ($localdir eq "") {
      $localdir = $curopt;
      if (! -d $localdir) { print "Local directory does not exist: " . $localdir . "\n"; $returncode+=1; }
      if ($remoteURL eq "") { $syncdirection="put"; }
    } else {  
      print "ERROR: Unknown parameter: \"" . $curopt . "\"\n"; $returncode+=1 
    }
  }      
}

if ($dodebug) { print_options(); }

# check options
if ($localdir  eq "") { print "ERROR: No localdir given.\n";  $returncode+=1; }
if ($remoteURL eq "") { print "ERROR: No remoteURL given.\n"; $returncode+=1; }
if ($returncode > 0) { die "Aborting due to missing options! Call ftpsync -? for more information.\n";  }

# parse remoteURL
if ($remoteURL =~ /^ftp:\/\/([^@\/\\\:]+):([^@\/\\\:]+)@([a-zA-Z01-9\.]+)\/(.+)/) {
  $ftpuser=$1;
  $ftppasswd=$2;
  $ftpserver=$3;
  $ftpdir=$4;
  #print "FTP's user, password, server, dir are:\n$ftpuser\n$ftppasswd\n$ftpserver\n$ftpdir\n";
}

# Build local tree
#chdir $localdir;
my $ldl=length($localdir) + 1;
my %localfiledates=();
my %localfilesizes=();
my %localdirs=();
if ($doverbose) { print "Building local file tree.\n"; }
find (\&noticelocalfile, $localdir . "/");
sub noticelocalfile {
  my $relfilename=substr($File::Find::name,$ldl);
  if (length($relfilename) == 0) { return; }
  my @curfilestat=lstat($File::Find::name);
  my $curfilesize=@curfilestat[7];
  my $curfilemdt=@curfilestat[9];
  if (-d $_) {
    #print "d " . $File::Find::name . "\n";
    $localdirs{$relfilename}="$relfilename";
  } 
  elsif (-f $_) {
    #print "f " . $File::Find::name . "(modified " . $curfilemdt . ", size " . $curfilesize . " bytes)\n";
    $localfiledates{$relfilename}=$curfilemdt;
    $localfilesizes{$relfilename}=$curfilesize;
  } else {
    #print "u " . $File::Find::name . "\n";
    print "Ignoring file of unknown type: " . $File::Find::name . "\n";
  }
  #print "File mode is " . @curfilestat[2] . "\n";
}
if ($dodebug) {
  print "Local dirs (relative to " . $localdir . "/):\n";
  my $curlocaldir="";
  foreach $curlocaldir (keys(%localdirs))
  { print $curlocaldir . "/\n"; }
  print "Local files (relative to " . $localdir . "/):\n";
  my $curlocalfile="";
  foreach $curlocalfile (keys(%localfiledates))
  { print $curlocalfile . "\n"; }
}  

# Build remote tree
my $ftpc = Net::FTP->new($ftpserver);
$ftpc->login($ftpuser,$ftppasswd);
$ftpc->cwd($ftpdir);
my %remotefilesizes=();
my %remotefiledates=();
my %remotedirs=();
my $curremotesubdir="";
if ($doverbose) { print "Building remote file tree.\n"; }
buildremotetree();

sub buildremotetree() {
  my @currecursedirs=();
  my @rfl=$ftpc->ls();
  my $currf="";
  if ($dodebug) { print "Remote pwd is " . $ftpc->pwd(); }
  foreach $currf (@rfl) {
    #print "Analysing remote file/dir " . $currf . "\n";
    if ($currf eq ".") { next; }
    if ($currf eq "..") { next; }
    my $currfmdt=$ftpc->mdtm($currf);
    my $currfsize=$ftpc->size($currf);
    if ( ($currfmdt  eq "") || ($currfsize eq "") ) 
    { if ($curremotesubdir eq "") { $remotedirs{$currf}=$currf; }
      else                        { $remotedirs{$curremotesubdir . "/" . $currf}=$curremotesubdir . "/" . $currf; }
      push @currecursedirs, $currf; }
    else
    { if ($curremotesubdir eq "") 
      { $remotefiledates{$currf}=$currfmdt;
        $remotefilesizes{$currf}=$currfsize; }
      else
      { $remotefiledates{$curremotesubdir . "/" . $currf}=$currfmdt;
        $remotefilesizes{$curremotesubdir . "/" . $currf}=$currfsize;
      }
    }
  }
  #recurse
  my $currecurseddir;
  foreach $currecurseddir (@currecursedirs)
  { my $oldcurremotesubdir;
    $oldcurremotesubdir=$curremotesubdir;
    if ($curremotesubdir eq "") { $curremotesubdir = $currecurseddir; }
    else                        { $curremotesubdir .= "/" . $currecurseddir; }
    $ftpc->cwd($currecurseddir);
    buildremotetree();
    $ftpc->cdup();
    $curremotesubdir = $oldcurremotesubdir;
  }
}
if ($dodebug) {
  print "remote dirs (relative to " . $ftpdir . "/):\n";
  my $curremotedir="";
  foreach $curremotedir (keys(%remotedirs))
  { print $curremotedir . "/\n"; }
  print "remote files (relative to " . $ftpdir . "/):\n";
  my $curremotefile="";
  foreach $curremotefile (keys(%remotefiledates))
  { print $curremotefile . "\n"; }
}  

# Work ...
chdir $localdir;
if ($syncdirection eq "put") {
  # delete files too much at the target
  my $curremotefile;
  foreach $curremotefile (keys(%remotefiledates)) 
  { if (not exists $localfiledates{$curremotefile})
    { if ($doinfoonly) { print "Would remove remote file " . $curremotefile . "\n"; next; }
      if ($doverbose)  { print "Removing remote file " . $curremotefile . "\n"; }
      $ftpc->delete($curremotefile);
    }
  }
  # delete dirs too much at the target
  my $curremotedir;
  foreach $curremotedir (sort { return length($b) <=> length($a); } keys(%remotedirs))
  { if (! exists $localdirs{$curremotedir})
    { if ($doinfoonly) { print "Would remove remote directory " . $curremotedir . "\n"; next; }
      if ($doverbose)  { print "Removing remote directory " . $curremotedir . "\n"; }
      $ftpc->rmdir($curremotedir);
    }
  }
  # create dirs missing at the target
  my $curlocaldir;
  foreach $curlocaldir (sort { return length($a) <=> length($b); } keys(%localdirs))
  { if (! exists $remotedirs{$curlocaldir})
    { if ($doinfoonly) { print "Would create remote directory " . $curlocaldir . "\n"; next; }
      if ($doverbose)  { print "Creating remote directory " . $curlocaldir . "\n"; }
      $ftpc->mkdir($curlocaldir);
    }
  }
  # copy files missing or too old at the target, synchronize timestamp _after_ copying
  my $curlocalfile;
  foreach $curlocalfile (keys(%localfiledates))
  { my $dorefresh=0;
    if    (! exists $remotefiledates{$curlocalfile}) { 
      $dorefresh=1; 
      if ($doinfoonly) { print "Would create remote file " . $curlocalfile . "\n"; next; }
      if ($doverbose)  { print "Creating remote file " . $curlocalfile . "\n"; }
    }
    elsif ($remotefiledates{$curlocalfile} != $localfiledates{$curlocalfile}) { 
      $dorefresh=1;
      if ($doinfoonly) { print "Would refresh remote file " . $curlocalfile . "\n"; next; }
      if ($doverbose)  { print "Refreshing remote file " . $curlocalfile . "\n"; }
    }
    if (! $dorefresh) { next; }
    if ($dodebug) { print "Really PUTting file " . $curlocalfile . "\n"; }
    $ftpc->put($curlocalfile, $curlocalfile);
    my $newremotemdt=$ftpc->mdtm($curlocalfile);
    utime ($newremotemdt, $newremotemdt, $curlocalfile);
  }
} else { # $syncdirection eq "GET"
  # delete files too much at the target
  my $curlocalfile;
  foreach $curlocalfile (sort { return length($b) <=> length($a); } keys(%localfiledates)) 
  { if (not exists $remotefiledates{$curlocalfile})
    { if ($doinfoonly) { print "Would remove local file " . $curlocalfile . "\n"; next; }
      if ($doverbose)  { print "Removing local file " . $curlocalfile . "\n"; }
      unlink($curlocalfile);
    }
  }
  # delete dirs too much at the target
  my $curlocaldir;
  foreach $curlocaldir (keys(%localdirs))
  { if (! exists $remotedirs{$curlocaldir})
    { if ($doinfoonly) { print "Would remove local directory " . $curlocaldir . "\n"; next; }
      if ($doverbose)  { print "Removing local directory " . $curlocaldir . "\n"; }
      rmdir($curlocaldir);
    }
  }
  # create dirs missing at the target
  my $curremotedir;
  foreach $curremotedir (sort { return length($a) <=> length($b); } keys(%remotedirs))
  { if (! exists $localdirs{$curremotedir})
    { if ($doinfoonly) { print "Would create local directory " . $curremotedir . "\n"; next; }
      if ($doverbose)  { print "Creating local directory " . $curremotedir . "\n"; }
      mkdir($curremotedir);
    }
  }
  # copy files missing or too old at the target, synchronize timestamp _after_ copying
  my $curremotefile;
  foreach $curremotefile (keys(%remotefiledates))
  { my $dorefresh=0;
    if    (! exists $localfiledates{$curremotefile}) { 
      $dorefresh=1; 
      if ($doinfoonly) { print "Would create local file " . $curremotefile . "\n"; next; }
      if ($doverbose)  { print "Creating local file " . $curremotefile . "\n"; }
    }
    elsif ($localfiledates{$curremotefile} != $remotefiledates{$curremotefile}) { 
      $dorefresh=1;
      if ($doinfoonly) { print "Would refresh local file " . $curremotefile . "\n"; next; }
      if ($doverbose)  { print "Refreshing local file " . $curremotefile . "\n"; }
    }
    if (! $dorefresh) { next; }
    if ($dodebug) { print "Really GETting file " . $curremotefile . "\n"; }
    $ftpc->get($curremotefile, $curremotefile);
    my $newlocalmdt=$remotefiledates{$curremotefile};
    utime ($newlocalmdt, $newlocalmdt, $curremotefile);
  }
}

exit 0;



#
# Subs
#

sub print_syntax() {
  print "\nThe correct syntax is:\n\n";
  print " ftpsync [-dgpqv] [ cfg=configfile ] [ localdir remoteURL ]\n";
  print " ftpsync [-dgpqv] [ cfg=configfile ] [ remoteURL localdir ]\n";
  print "   configfile  read parameters and options from file. NOT IMPLEMENTED YET!";
  print "   -d | -D     turns debug output (including verbose output) on\n";
  print "   -g | -G     forces sync direction to GET (remote to local)\n";
  print "   -h | -H     turns debugging on\n";
  print "   -i | -I     forces info mode, only telling what would be done\n";
  print "   -p | -P     forces sync direction to PUT (local to remote)\n";
  print "   -q | -Q     turnes quiet operation on\n";
  print "   -v | -V     turnes verbose output on\n";
  print "Later mentioned options and parameters overwrite those metioned erlier.\n";
  print "Command line options and parameters overwrite those in the config file.\n";
  print "\n";
}

sub print_options() {
  print "\nPrinting options:\n";
  # meta
  print "returncode    = ", $returncode    , "\n";
  print "configfile    = ", $configfile    , "\n";
  # basiscs
  print "localdir      = ", $localdir      , "\n";
  print "remoteURL     = ", $remoteURL     , "\n";
  print "syncdirection = ", $syncdirection , "\n";
  # verbsityosity
  print "doverbose     = ", $doverbose     , "\n";
  print "dodebug       = ", $dodebug       , "\n";
  print "doquiet       = ", $doquiet       , "\n";
  #
  print "doinfoonly    = ", $doinfoonly    , "\n";
  print "\n";
}
