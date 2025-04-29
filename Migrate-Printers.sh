#!/bin/bash

launchctl unload -w /System/Library/LaunchDaemons/org.cups.cupsd.plist
cp /etc/cups/printers.conf /etc/cups/printers.conf.bak
sed -i '' 's/\/prntsrv.somewhere.local\//\/printers.somewhere.local\//g' /etc/cups/printers.conf
launchctl load -w /System/Library/LaunchDaemons/org.cups.cupsd.plist
