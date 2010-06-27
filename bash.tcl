#
# June 26 2010
# by horgh
#
# Requires Tcl 8.5+ and tcllib
#
# Must .chanset #channel +bash
#
# Usage: !bash [optional search terms]
# If search terms are not provided, fetch random quotes.
#
# Keeps fetched quotes in memory until displayed, including all results per
# search term
#

package require http
package require htmlparse

namespace eval bash {
	variable trigger !bash
	variable line_length 400
	variable max_lines 10

	variable useragent "Mozilla/5.0 (compatible; Y!J; for robot study; keyoshid)"

	variable output_cmd putserv

	setudef flag bash
	bind pub -|- $bash::trigger bash::handler

	variable url http://bash.org/?

	variable list_regexp {<p class="quote">.*?<p class="qt">.*?</p>}
	variable quote_regexp {<p class="quote">.*?<b>#(.*?)</b>.*?class="qa".*?</a>\((.*?)\)<a.*?<p class="qt">(.*?)</p>}

	if {![info exists random_quotes]} {
		variable random_quotes []
	}
	if {![info exists search_quotes]} {
		variable search_quotes []
	}
}

proc bash::quote_output {chan quote} {
	set number [dict get $quote number]
	set rating [dict get $quote rating]
	set quote [htmlparse::mapEscapes [dict get $quote quote]]
	set quote [regsub -all -- {<br />} $quote ""]

	$bash::output_cmd "PRIVMSG $chan :#\002${number}\002 (Rating: ${rating})"
	foreach line [split $quote \n] {
		if {[incr count] > $bash::max_lines} {
			$bash::output_cmd "PRIVMSG $chan :Output truncated. ${bash::url}${number}"
			break
		} else {
			foreach subline [bash::split_line $bash::line_length $line] {
				$bash::output_cmd "PRIVMSG $chan :$subline"
			}
		}
	}
}

proc bash::handler {nick uhost hand chan argv} {
	if {![channel get $chan bash]} { return }
	if {$argv == ""} {
		if {[catch {bash::random $chan} result]} {
			$bash::output_cmd "PRIVMSG $chan :Error: $result"
			return
		} else {
			bash::quote_output $chan $result
		}
	} else {
		if {[catch {bash::search $argv $chan} result]} {
			$bash::output_cmd "PRIVMSG $chan :Error: $result"
			return
		} else {
			bash::quote_output $chan $result
		}
	}
}

proc bash::random {} {
	if {![llength $bash::random_quotes]} {
		$bash::output_cmd "PRIVMSG $chan :Fetching new random quotes..."
		set bash::random_quotes [bash::fetch ${bash::url}random1]
	}
	set quote [lindex $bash::random_quotes 0]
	set bash::random_quotes [lreplace $bash::random_quotes 0 0]
	return $quote
}

proc bash::search {query} {
	if {![dict exists $bash::search_quotes $query]} {
		$bash::output_cmd "PRIVMSG $chan :Fetching results..."
		set url ${bash::url}[http::formatQuery search $query sort 0 show 25]
		dict set bash::search_quotes $query [bash::fetch $url]
	}
	set quotes [dict get $bash::search_quotes $query]
	set quote [lindex $quotes 0]
	set quotes [lreplace $quotes 0 0]

	# Remove key if no more quotes after removal of one, else set quotes to remaining
	if {![llength $quotes]} {
		dict unset bash::search_quotes $query
	} else {
		dict set bash::search_quotes $query $quotes
	}

	return $quote
}

proc bash::fetch {url} {
	putlog "Fetching new bash.org quotes: $url"

	http::config -useragent $bash::useragent
	set token [http::geturl $url -timeout 10000]
	set data [http::data $token]
	set ncode [http::ncode $token]
	http::cleanup $token

	if {$ncode != 200} {
		error "HTTP fetch error $ncode: $data"
	}

	return [bash::parse $data]
}

proc bash::parse {html} {
	set quotes []
	foreach raw_quote [regexp -all -inline -- $bash::list_regexp $html] {
		if {[regexp $bash::quote_regexp $raw_quote -> number rating quote]} {
			lappend quotes [list number $number rating $rating quote $quote]
		} else {
			error "Parse error"
		}
	}

	return $quotes
}

# by fedex
proc bash::split_line {max str} {
	set last [expr {[string length $str] -1}]
	set start 0
	set end [expr {$max -1}]

	set lines []

	while {$start <= $last} {
		if {$last >= $end} {
			set end [string last { } $str $end]
		}

		lappend lines [string trim [string range $str $start $end]]
		set start $end
		set end [expr {$start + $max}]
	}

	return $lines
}

putlog "bash.tcl loaded"
