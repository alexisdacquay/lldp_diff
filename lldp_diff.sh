#!/bin/bash
# by Alexis Dacquay, ad@arista.com
# version 0.4
#
# examples of aliases and command example to setup the above
# !
# schedule lldp_diff interval 60 max-log-files 10 command bash /mnt/flash/lldp_diff.sh
# !

LOC='/mnt/flash/schedule/lldp_diff'
# Create the directory if it does not exist
mkdir -p $LOC
cd $LOC
# debug: echo `pwd`
# Move the "latest" capture as "previous" (aka old). "2> /dev/null" to silent in case "latest" does not exist yet (e.g. at 1st run)
mv lldp_diff-latest lldp_diff-previous 2> /dev/null
# Capture of the LLDP table, skipping the first line since it would always be different (e.g. Last table change time   : 2:00:44 ago)
FastCli -p 15 -c $'show lldp neighbors | tail -n +2' > $LOC/lldp_diff-latest

# Optional: for historical storage, uncomment the two below lines (you must tidy yourself after a while)
# NOW=$(date +%Y-%m-%d.%H%M%S)
# cp lldp_diff-latest lldp_diff-$NOW

DIFF=$(diff lldp_diff-latest lldp_diff-previous)
if [ "$DIFF" != "" ] 
then
    echo "$DIFF" | email -i -s "[LLDP Diff on $HOSTNAME]" ad.arista.01@gmail.com
fi

