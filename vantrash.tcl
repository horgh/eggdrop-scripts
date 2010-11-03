#
# 2010-10-03
#
# Notify specific channels when garbage pickup is next day
# Uses next-day API from http://vantrash.ca
#

package require http

namespace eval vantrash {
	# corresponds to zone name on vantrash.ca
	set zone "vancouver-north-blue"
	set url "http://vantrash.ca/zones/${zone}/nextpickup.txt"

	# where to output
	set channel #newhell

	bind time - {30 21 * * *} vantrash::check
}

proc vantrash::check {min hour day month year} {
	set token [http::geturl $vantrash::url]
	set data [http::data $token]
	http::cleanup $token

	set next_date [lindex [split $data] 0]
	set next_date [clock scan $next_date]
	set next_day [string trim [clock format $next_date -format %e]]

	set tomorrow_day [string trim [clock format [clock scan tomorrow] -format %e]]
	if {$next_day == $tomorrow_day} {
		putserv "PRIVMSG $vantrash::channel :Garbage day tomorrow!"
	} else {
		putserv "PRIVMSG $vantrash::channel :next_day $next_day tomorrow_day $tomorrow_day ."
	}
}

putlog "vantrash.tcl loaded"
