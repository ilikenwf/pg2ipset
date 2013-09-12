pg2ipset - Originally written by Maeyanie.com 
Improvements/fixes added by ilikenwf and whoever puts in pull requests

========
ABOUT
========

info: http://www.maeyanie.com/2008/12/efficient-iptables-peerguardian-blocklist/

pg2ipset takes the contents of PG2 IP Blocklists and outputs lists that
ipset under Linux can consume, for more efficient blocking than most 
other methods.


========
INSTALLATION
========

make build && make install 
(or just run make as root)

========
USAGE
========

To import from a .txt list from bluetack:
	cat /path/to/blocklist.txt | pg2ipset - - listname | ipset restore

To import from a .gz list:
	zcat /path/to/blocklist.gz | pg2ipset - - listname | ipset restore

Help text:
	Usage: ./pg2ipset [<input> [<output> [<set name>]]]
	Input should be a PeerGuardian .p2p file, blank or '-' reads from stdin.
	Output is suitable for usage by 'ipset restore', blank or '-' prints to stdout.
	Set name is 'IPFILTER' if not specified.
	Example: curl http://www.example.com/guarding.p2p | ./pg2ipset | ipset restore
	

IMPORTANT!!!
	Once you've created your ipsets and imported them as mentioned above, 
	you'll need iptables rules for each of them to do the actual blocking.
	
	To block any traffic coming in from addresses in "listname:"
		iptables -A INPUT -m set --set listname src -j DROP
		iptables -A FORWARD -m set --set listname src -j DROP
	
	To block any traffic going out to an address in "listname:"
		iptables -A FORWARD -m set --set listname dst -j REJECT
		iptables -A OUTPUT -m set --set listname dst -j REJECT

========
AUTOMATIC LIST UPDATING
========

I have included my ipset-update.sh script, which I run on a daily 
cron job. Please read through and edit it to your desires, should you
want to automatically update your blocklists.

========
LICENSE
========

	pg2ipset.c - Convert PeerGuardian lists to IPSet scripts.
	Copyright (C) 2009-2010, me@maeyanie.com

	This program is free software; you can redistribute it and/or modify
	it under the terms of the GNU General Public License as published by
	the Free Software Foundation; either version 2 of the License, or
	(at your option) any later version.

	This program is distributed in the hope that it will be useful,
	but WITHOUT ANY WARRANTY; without even the implied warranty of
	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
	GNU General Public License for more details.

	You should have received a copy of the GNU General Public License along
	with this program; if not, write to the Free Software Foundation, Inc.,
	51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
