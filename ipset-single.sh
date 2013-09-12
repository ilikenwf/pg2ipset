#!/bin/bash

# ipset-update.sh (C) 2012 Matt Parnell http://www.mattparnell.com
# Licensed under the GNU-GPLv2+

# place to keep our cached blocklists
LISTDIR="/var/cache/blocklists"
SET="IPFILTER"

# create cache directory for our lists if it isn't there
[ ! -d $LISTDIR ] && mkdir $LISTDIR

lists=(badpeers level1 level2 level3 spyware dshield bogon templist iana-multicast iana-reserved hijacked proxy ads-trackers-and-bad-pr0n)

ipset create -exist $SET hash:net family inet maxelem 4294967295
ipset create -exist $SET-TMP hash:net family inet maxelem 4294967295
ipset flush $IPFILTER-TMP &> /dev/null

for list in ${lists[@]}
do
        if [ eval $(curl -s -L http://www.bluetack.co.uk/config/$list.gz -o /tmp/$list.gz) ]; then
                mv /tmp/$list.gz $LISTDIR/$list.gz
        else
                echo "Using cached list for $list."
        fi

        zcat $LISTDIR/$list.gz | pg2ipset - - $SET-TMP | ipset restore
done

if [ eval $(curl -s -L http://ipinfodb.com/country_query.php?country=AF,AE,IR,IQ,TR,CN,SA,SY,RU,UA,HK,ID,KZ,KW,LY -o /tmp/countries.txt) ]; then
        mv /tmp/countries.txt $LISTDIR/countries.txt
else
        echo "Using cached list of blocked countries."
fi

awk '!x[$0]++' $LISTDIR/countries.txt | sed -e "s/^/\-A\ \-exist\ $SET-TMP\ /" | ipset restore
awk '!x[$0]++' $LISTDIR/Custom.txt | sed -e "s/^/\-A\ \-exist\ $SET-TMP\ /" | ipset restore

ipset swap $SET $SET-TMP
ipset destroy $SET-TMP
