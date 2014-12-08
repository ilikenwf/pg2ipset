#!/bin/bash

# ipset-update.sh (C) 2012-2015 Matt Parnell http://www.mattparnell.com
# Licensed under the GNU-GPLv2+

# place to keep our cached blocklists
LISTDIR="/var/cache/blocklists"

# create cache directory for our lists if it isn't there
[ ! -d $LISTDIR ] && mkdir $LISTDIR

# countries to block, must be lcase
COUNTRIES=(af ae ir iq tr cn sa sy ru ua hk id kz kw ly)

# bluetack lists to use - they now obfuscate these so get them from
# https://www.iblocklist.com/lists.php
BLUETACK=(ydxerpxkpcfqjaybcssw gyisgnzbhppbvsphucsw uwnukjqktoggdknzrhgh llvtlsjyoyiczbkjsxpf xpbqleszmajjesnzddhv lujdnbasfaaixitgmxpp dufcxgnbjsdwmwctgfuj bcoepfyewziejvcqyhqo pwqnlynprfgtjbgqoizj usrcshglbiilevmyfhse zbdlwrqkabxbcppvrnos usrcshglbiilevmyfhse ficutxiwawokxlcyoeye ghlzqtqxnzctvvajwwag)

# ports to block tor users from
PORTS=(80 443 6667 22 21)

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

#cache a copy of the iptables rules
IPTABLES=$(iptables-save)

importList(){
  if [ -f $LISTDIR/$1.txt ] || [ -f $LISTDIR/$1.gz ]; then
	echo "Importing $1 blocks..."
	
	ipset create -exist $1 hash:net maxelem 4294967295
	ipset create -exist $1-TMP hash:net maxelem 4294967295
	ipset flush $1-TMP &> /dev/null
	
	#the second param determines if we need to use zcat or not
	if [ $2 = 1 ]; then
	  zcat $LISTDIR/$1.gz | grep  -v \# | grep -v ^$ | pg2ipset - - $listname-TMP | ipset restore
	else
	  awk '!x[$0]++' $LISTDIR/$1.txt | grep  -v \# | grep -v ^$ | ipset restore
	fi
	
	ipset swap $1 $1-TMP
	ipset destroy $1-TMP
	
	# only create if the iptables rules don't already exist
	if ! echo $IPTABLES|grep -q "\-A\ INPUT\ \-m\ set\ \-\-match\-set\ $1\ src\ \-\j\ DROP"; then
	  iptables -A INPUT -m set --match-set $1 src -j DROP
	  iptables -A FORWARD -m set --match-set $1 src -j DROP
	  iptables -A FORWARD -m set --match-set $1 dst -j REJECT
	  iptables -A OUTPUT -m set --match-set $1 dst -j REJECT
	fi
  else
	echo "List $1.txt does not exist."
  fi
}

if [ $ENABLE_BLUETACK = 1 ]; then
  # get, parse, and import the bluetack lists
  # they are special in that they are gz compressed and require
  # pg2ipset to be inserted
  i=1
  for list in ${BLUETACK[@]}; do
	listname="bluetack$i"
  
	if [ eval $(wget --quiet -O /tmp/$listname.gz http://list.iblocklist.com/?list=$list&fileformat=p2p&archiveformat=gz) ]; then
	  mv /tmp/$listname.gz $LISTDIR/$listname.gz
	else
	  echo "Using cached list for $list."
	fi
	
	echo "Importing bluetack list $list..."
  
	importList $listname 1
	
	i=$((i+1))
  done
fi

if [ $ENABLE_COUNTRY = 1 ]; then
  # get the country lists and cat them into a single file
  for country in ${COUNTRIES[@]}; do
	if [ eval $(wget --quiet -O /tmp/$country.txt http://www.ipdeny.com/ipblocks/data/countries/$country.zone) ]; then
	  cat /tmp/$country.txt >> $LISTDIR/countries.txt
	  rm /tmp/$country.txt
	fi
  done
  
  importList "countries" 0
fi


if [ $ENABLE_TORBLOCK = 1 ]; then
  # get the tor lists and cat them into a single file
  for ip in $(ip -4 -o addr | awk '!/^[0-9]*: ?lo|link\/ether/ {gsub("/", " "); print $4}'); do
	for port in ${PORTS[@]}; do
	  if [ eval $(wget --quiet -O /tmp/$port.txt https://check.torproject.org/cgi-bin/TorBulkExitList.py?ip=$ip&port=$port) ]; then
		cat /tmp/$port.txt >> $LISTDIR/tor.txt
		rm /tmp/$port.txt
	  fi
	done
  done 
  
  importList "tor" 0
fi

# add any custom import lists below
# ex: importTextList "custom"
