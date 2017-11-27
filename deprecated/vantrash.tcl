#
# 2010-10-03
#
# Notify specific channels when garbage pickup is next day
# Uses next-day API from http://vantrash.ca
#

package require http

namespace eval vantrash {
	# corresponds to zone name on vantrash.ca
	variable zone "vancouver-north-blue"
	variable url "http://vantrash.ca/zones/${zone}/nextpickup.txt"

	# where to output
	variable channel #tea

	# min hr day month year
	bind time - {30 19 * * *} vantrash::check
	bind time - {30 20 * * *} vantrash::check
	bind time - {30 21 * * *} vantrash::check

	bind pub -|- "!vantrash" vantrash::handler

	variable cached_date []
}

proc vantrash::handler {nick uhost hand chan argv} {
	vantrash::check * * * * *
}

proc vantrash::check {min hour day month year} {
	# Only fetch new date if we haven't yet found one, or that one is past
	if {$vantrash::cached_date == "" || [clock seconds] > $vantrash::cached_date} {
		set token [http::geturl $vantrash::url]
		set data [http::data $token]
		set ncode [http::ncode $token]
		http::cleanup $token

		if {$ncode != 200} {
			putserv "PRIVMSG $vantrash::channel :(vantrash) Error (${ncode}) fetching next pickup date. (Cached date is expired or not present): ${data}"
			return
		}

		set next_date [lindex [split $data] 0]
		set vantrash::cached_date [clock scan $next_date]
	}

	set next_day [string trim [clock format $vantrash::cached_date -format %e]]
	set tomorrow_day [string trim [clock format [clock scan tomorrow] -format %e]]

	if {$next_day == $tomorrow_day} {
		putserv "PRIVMSG $vantrash::channel :Garbage day tomorrow!"
	}
}

putlog "vantrash.tcl loaded"
