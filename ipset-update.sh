#!/bin/bash

# ipset-update.sh (C) 2012-2015 Matt Parnell http://www.mattparnell.com
# Licensed under the GNU-GPLv2+

# place to keep our cached blocklists
LISTDIR="/var/cache/blocklists"

# create cache directory for our lists if it isn't there
[ ! -d $LISTDIR ] && mkdir $LISTDIR

# countries to block, must be lcase
COUNTRIES=(af,ae,ir,iq,tr,cn,sa,sy,ru,ua,hk,id,kz,kw,ly)

# bluetack lists to use
BLUETACK=(badpeers level1 level2 level3 spyware dshield bogon templist iana-multicast iana-reserved hijacked proxy ads-trackers-and-bad-pr0n)

# ports to block tor users from
PORTS=(80,443,6667,22,3306)

# remove old countries list
[ -f $LISTDIR/countries.txt ] && rm $LISTDIR/countries.txt

# remove the old tor node list
[ -f $LISTDIR/tor.txt ] && rm $LISTDIR/tor.txt

# enable bluetack lists?
ENABLE_BLUETACK=1

# enable country blocks?
ENABLE_COUNTRY=1

# enable tor blocks?
ENABLE_TORBLOCK=1

# enable custom blocks?
ENABLE_CUSTOM=1

importTextList(){
	if [ -f $LISTDIR/$1.txt ]; then
		echo "Importing $1 blocks..."
		ipset create -exist countries hash:net maxelem 4294967295
		ipset create -exist countries-TMP hash:net maxelem 4294967295
		ipset flush countries-TMP &> /dev/null
		awk '!x[$0]++' $LISTDIR/$1.txt | sed -e "s/^/\-A\ \-exist\ $1\ /" | ipset restore
		ipset swap countries $1-TMP
		ipset destroy $1-TMP
		
		# if they aren't already there, go ahead and setup block rules
		# in iptables
		iptables -A INPUT -m set --match-set $1 src -j DROP
		iptables -A FORWARD -m set --match-set $1 src -j DROP
		iptables -A FORWARD -m set --match-set $1 dst -j REJECT
		iptables -A OUTPUT -m set --match-set $1 dst -j REJECT
	else
		echo "List $1.txt does not exist."
	fi
}

if [ $ENABLE_BLUETACK==1 ]; then
	# get, parse, and import the bluetack lists
	# they are special in that they are gz compressed and require
	# pg2ipset to be inserted
	for list in ${BLUETACK[@]}; do
			if [ eval $(curl -s -L http://www.bluetack.co.uk/config/$list.gz -o /tmp/$list.gz) ]; then
					mv /tmp/$list.gz $LISTDIR/$list.gz
			else
					echo "Using cached list for $list."
			fi

			ipset create -exist $list hash:net family inet maxelem 4294967295
			ipset create -exist $list-TMP hash:net family inet maxelem 4294967295
			ipset flush $list-TMP &> /dev/null
			zcat $LISTDIR/$list.gz | pg2ipset - - $list-TMP | ipset restore
			ipset swap $list $list-TMP
			ipset destroy $list-TMP
	done
fi

if [ $ENABLE_COUNTRY==1 ]; then
	# get the country lists and cat them into a single file
	for country in ${COUNTRIES[@]}; do
			if [ eval $(curl -s -L http://www.ipdeny.com/ipblocks/data/countries/$country.zone -o /tmp/$country.txt) ]; then
					cat /tmp/$country.txt >> $LISTDIR/countries.txt
					rm /tmp/$country.txt
			fi
	done
	
	importTextList "countries"
fi


if [ $ENABLE_TORBLOCK==1 ]; then
	# get the tor lists and cat them into a single file
	for ip in $(ip -4 -o addr | awk '!/^[0-9]*: ?lo|link\/ether/ {gsub("/", " "); print $4}'); do
			for port in ${PORTS[@]}; do
				if [ eval $(curl -s -L https://check.torproject.org/cgi-bin/TorBulkExitList.py?ip=$ip&port=$port -o /tmp/$port.txt) ]; then
						cat /tmp/$port.txt >> $LISTDIR/tor.txt
						rm /tmp/$port.txt
				fi
			done
	done 
	
	importTextList "tor"
fi

if [ $ENABLE_CUSTOM==1 ]; then
	importTextList "custom"
fi
