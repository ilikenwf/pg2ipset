#!/bin/bash

# ipset-update.sh (C) 2012 Matt Parnell http://www.mattparnell.com
# Licensed under the GNU-GPLv2+

# place to keep our cached blocklists
LISTDIR="/var/cache/blocklists"

# create cache directory for our lists if it isn't there
[ ! -d $LISTDIR ] && mkdir $LISTDIR

lists=(badpeers level1 level2 level3 spyware dshield bogon templist iana-multicast iana-reserved hijacked proxy ads-trackers-and-bad-pr0n)

for list in ${lists[@]}
do
        if [ eval $(curl -s -L http://www.bluetack.co.uk/config/$list.gz -o /tmp/$list.gz) ]; then
                mv /tmp/$list.gz $LISTDIR/$list.gz
        else
                echo "Using cached list for $list."
        fi

        ipset create -exist $list hash:net family inet maxelem 4294967295
        ipset create -exist $list-TMP hash:net family inet maxelem 4294967295
        ipset flush $list-TMP &> /dev/null
        zcat $LISTDIR/$list.gz | pg2ipset - - $list-TMP | ipset -R
        ipset -W $list $list-TMP
        ipset -X $list-TMP
done

if [ eval $(curl -L http://ipinfodb.com/country_query.php?country=AF,AE,IR,IQ,TR,CN,SA,SY,RU,UA,HK,ID,KZ,KW,LY -o /tmp/countries.txt) ]; then
        mv /tmp/countries.txt $LISTDIR/countries.txt
else
        echo "Using cached list of blocked countries."
fi

echo "Importing country blocks..."
ipset create -exist countries hash:net maxelem 4294967295
ipset create -exist countries-TMP hash:net maxelem 4294967295
ipset flush countries-TMP &> /dev/null
awk '!x[$0]++' $LISTDIR/countries.txt | sed -e 's/^/\-A\ \-exist\ countries\ /' | ipset -R
ipset -W countries countries-TMP
ipset -X countries-TMP


echo "Importing Custom blocks..."
ipset create -exist Custom hash:net maxelem 4294967295
ipset create -exist Custom-TMP hash:net maxelem 4294967295
ipset flush Custom-TMP &> /dev/null
awk '!x[$0]++' $LISTDIR/Custom.txt | sed -e 's/^/\-A\ \-exist\ Custom\ /' | ipset -R
ipset -W Custom Custom-TMP
ipset -X Custom-TMP
