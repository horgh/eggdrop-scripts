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
	variable channel #newhell

	# min hr day month year
	bind time - {30 21 * * *} vantrash::check

	variable cached_date []
}

proc vantrash::check {min hour day month year} {
	# Only fetch new date if we haven't yet found one, or that one is past
	if {$vantrash::cached_date == "" || [clock seconds] > $vantrash::cached_date} {
		set token [http::geturl $vantrash::url]
		set data [http::data $token]
		http::cleanup $token

		set next_date [lindex [split $data] 0]
		set vantrash::cached_date [clock scan $next_date]
		putserv "PRIVMSG $vantrash::channel :(vantrash) Got new date"
	} else {
		putserv "PRIVMSG $vantrash::channel :(vantrash) Date is cached"
	}

	set next_day [string trim [clock format $vantrash::cached_date -format %e]]
	set tomorrow_day [string trim [clock format [clock scan tomorrow] -format %e]]

	if {$next_day == $tomorrow_day} {
		putserv "PRIVMSG $vantrash::channel :Garbage day tomorrow!"
	} else {
		putserv "PRIVMSG $vantrash::channel :next_day $next_day tomorrow_day $tomorrow_day ."
	}
}

putlog "vantrash.tcl loaded"
