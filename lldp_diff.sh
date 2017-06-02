#!/bin/sh
# by Alexis Dacquay, ad@arista.com
# version 0.4
#
# examples of aliases and command example to setup the above
# !
# schedule lldp_diff interval 60 max-log-files 10 command bash /mnt/flash/lldp_diff.sh
# !

if [ $1 ]
    then FILES_TO_KEEP=$1
    else FILES_TO_KEEP='10'
fi
LOC='/mnt/flash/schedule/lldp_diff'
# MUST DO: change the below to a valid email address
EMAIL_DEST='user@domain.com'

# Create the directory if it does not exist
mkdir -p $LOC

# Move the "latest" capture as "previous" (aka old). "2> /dev/null" to silent
# in case "latest" does not exist yet (e.g. at 1st run)
mv $LOC/lldp_diff-latest $LOC/lldp_diff-previous 2> /dev/null

# Capture of the LLDP table, skipping the first line since it would always be 
# different (e.g. Last table change time   : 2:00:44 ago)
FastCli -p 15 -c $'show lldp neighbors | tail -n +2' > $LOC/lldp_diff-latest

# Historical records, uncompressed
NOW=$(date +%Y-%m-%d.%H%M%S)
cp $LOC/lldp_diff-latest $LOC/lldp_diff-$NOW

# IF there are too many files, we delete the older ones
if [ $(ls $LOC | wc -l) -gt $FILES_TO_KEEP ]
    then ls -t | tail -n +$FILES_TO_KEEP | xargs -d '\n' rm
fi

# Sending an email if there is a difference. '-N' is case '-previous' is nil
DIFF=$(diff -N $LOC/lldp_diff-latest $LOC/lldp_diff-previous)
if [ "$DIFF" != "" ] 
    then echo "$DIFF" | email -i -s "[LLDP Diff on $HOSTNAME]" $EMAIL_DEST
fi