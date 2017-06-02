#!/bin/bash
# by Alexis Dacquay, ad@arista.com
# version 0.6
# 
# Overview:
# ========
# This script captures the LLDP neighbour table and records its content in a 
# local text file. You may optionally receive an email if a difference is 
# detected comparing the current table with the previously known one. This 
# feature is only active if an email address is provided.
# 
# To prevent the file count from growing to large, older files are 
# automatically deleted. The amount of files to preserve can be explicitely 
# specified in arguments, or you may leave the default of 10.
# 
# 
# Usage
# =====
# 
# lldp_diff.sh [ -h|--help ][ -d|--debug ][ -n|--maxfile <Max file count> ] [ -e|--email <email address> ] 
# 
# 
# Examples
# ========
# 
# 1) Auto-execution with the EOS schedule manager
#    This is the recommended method.
# 
# ```
# schedule lldp_diff interval 60 max-log-files 10 command bash /mnt/flash/lldp_diff.sh -e user@domain.com
# ```
# 
# 2) Manual execution from EOS
#    For frequent execution you might want to set an alias.
# 
# ````
# bash /mnt/flash/lldp_diff.sh -e user@domain.com
# ````
# 
# 3) Examples of outputs you could expect
#    - manual use
#    - '--debug' for debug outputs
#    - '--email' to receive an email if a diff is detected.
# 
# ````
# arista#bash /mnt/flash/lldp_diff.sh --debug -email ad.arista.01@gmail.com
# Selected options:
# --maxfile: 10                                       <=== default
# --email: user@domain.com
# Storage location: /mnt/flash/schedule/lldp_diff     <=== hard-coded default
# Amount of files stored: 11                          <=== excess detected
# Max file number exceeded. Deleting older file(s)... <=== deletion to resolve
# lldp_diff-2017-06-02.151620                         <=== list the old file(s)
# Differences found, sending email...                 <=== an email is sent
# Please wait until this finishes...
# Enter your message below.  Hit ^D to finish the message. <== ignore, just wait
# Email Sent
# arista#
# ````
# 


# Defaults parameters
maxfile=10
LOC='/mnt/flash/schedule/lldp_diff'

# Debug helper
showdebug () {
    if [ $debug ]
        then echo "$1"
    fi
}

# CLI help
showhelp () {
        echo "Usage:"
        echo -e '\t' "lldp_diff.sh [options]"
        echo "Options:"
        echo -e '\t' "-d Debug mode"
        echo -e '\t' "-h This help"
        echo -e '\t' "-n Max number of files to preserve (default is 10)."
        echo -e '\t' "   If exceeding N, the oldest files will be deleted"
        echo -e '\t' "-e Destination email address. This is a mandatory argument."
}

# ---------- start of option parsing ----------
getopt --test > /dev/null
if [[ $? -ne 4 ]]
    then
        echo "I am sorry, `getopt --test` failed in this environment."
        exit 1
fi

# Options syntax (short and long)
SHORT=dhn:e:
LONG=debug,help,maxfile:,email:

# Temporarily store output to be able to check for errors
# activate advanced mode getopt quoting e.g. via “--options”
# pass arguments only via   -- "$@"   to separate them correctly
PARSED=$(getopt --options $SHORT --longoptions $LONG --name "$0" -- "$@")
if [[ $? -ne 0 ]]
    # e.g. $? == 1
    # then getopt has complained about wrong arguments to stdout
    then exit 2
fi

eval set -- "$PARSED"
while true; do
    case "$1" in
        -d|--debug)
            debug=y
            shift
            ;;
        -h|--help)
            showhelp
            exit 0
            ;;
        -n|--maxfile)
            maxfile="$2"
            shift 2
            ;;
        -e|--email)
            email="$2"
            shift 2
            ;;
        --)
            shift
            break
            ;;
        *)
            echo "Programming error"
            exit 3
            ;;
    esac
done
# ---------- end of option parsing ----------

# Debug to verify the options
if [ $debug ]
    then
        echo "Selected options:" 
        echo "--maxfile: $maxfile"
        if [ $email ]
            then echo "--email: $email"
            else echo "--email: NONE selected"
        fi
        echo "Storage location: $LOC"
fi

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

# Count the amount of records, excluding 2: 'latest' and 'previous'
filecount=$[ $(ls $LOC | wc -l) - 2]
showdebug "Amount of files stored: $filecount"

# If there are too many files, we delete the older ones
if [ $filecount -gt $maxfile ]
    then
        # '$maxfile + 3' for skipping 3 in the count: 
        # 2 permanent files we want to keep + 1 always awkward 'tail' thing
        lines_to_delete=$( ls -t | tail -n +$[ $maxfile + 3 ] )
        showdebug 'Max file number exceeded. Deleting older file(s)...' 
        showdebug $lines_to_delete
        echo $lines_to_delete | xargs -d '\n' rm
fi

# If the email was set as an option, otherwise don't send email (well, cannot)
if [ $email ]
    then
        # Sending an email if there is a diff. '-N' is case '-previous' is nil
        DIFF=$(diff -N $LOC/lldp_diff-latest $LOC/lldp_diff-previous)
        if [ "$DIFF" != "" ] 
            then
                showdebug 'Differences found, sending email...'
                echo "Please wait until this finishes..."
                echo "$DIFF" | email -i -s "[LLDP Diff on $HOSTNAME]" "$email"
                showdebug 'Email Sent'
        fi
fi
