#!/bin/bash

# ==============================================================================
# Find-Sophos.sh
#
#   Attempts to determine if Sophos is installed and updating correctly
#
# Chris :: 12/17/2012 @ 8:30 AM
# ==============================================================================

TestFile="encp-ahq.ide"
RemoteResults=/SophosCheck/
Host=`hostname`
HeadStamp=`date "+%m/%d/%Y @ %H:%M"`
FileStamp=`date "+%Y.%m.%d @ %H%M%S"`
FileName="$Host $FileStamp.log"
RemoteFile=$RemoteResults$FileName

# mount a share that we'll be using to log our results
mkdir /SophosCheck
mount_smbfs -o nobrowse //files.somewhere.local/SophosCheck /SophosCheck

# start our log file...
echo "Querying Sophos status of $Host on $HeadStamp" >> "$RemoteFile"

# is Sophos installed?
if test -e "/Library/Sophos Anti-Virus/SophosAntiVirus.app"; then
  echo "  Sophos IS installed." >> "$RemoteFile"
  # is Sophos up-to-date?
  if test -e "/Library/Sophos Anti-Virus/IDE/$TestFile"; then
    echo "    Sophos IS up-to-date." >> "$RemoteFile"
  else
    echo "    Sophos is NOT up-to-date." >> "$RemoteFile"
  fi
else
  echo "  Sophos is NOT installed." >> "$RemoteFile"
fi
echo " " >> "$RemoteFile"

# unmount the share
umount /SophosCheck
rmdir /SophosCheck