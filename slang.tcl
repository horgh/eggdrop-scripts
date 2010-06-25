#
# ud.tcl - June 24 2010
# by horgh
#
# Requires Tcl 8.5+ and tcllib
#
# Made with heavy inspiration from perpleXa's urbandict script!
#
# Must .chanset #channel +ud
#

package require htmlparse
package require http

namespace eval ud {
	# set this to !ud or whatever you want
	variable trigger "slang"

	# maximum lines to output
	variable max_lines 1

	variable output_cmd "putserv"

	variable client "Mozilla/5.0 (compatible; Y!J; for robot study; keyoshid)"
	variable url http://www.urbandictionary.com/define.php
	variable list_regexp {<td class='text'.*? id='entry_.*?'>.*?</td>}
	variable def_regexp {id='entry_(.*?)'>.*?<div class='definition'>(.*?)</div>}

	setudef flag ud
	bind pub -|- $ud::trigger ud::handler
}

proc ud::handler {nick uhost hand chan argv} {
	if {![channel get $chan ud]} { return }
	set argv [split $argv]
	if {[string is digit [lindex $argv 0]]} {
		set number [lindex $argv 0]
		set query [join [lrange $argv 1 end]]
	} else {
		set query [join $argv]
		set number 1
	}

	if {$query == ""} {
		$ud::output_cmd "PRIVMSG $chan :Usage: $ud::trigger \[#\] <definition to look up>"
		return
	}

	if {[catch {ud::fetch $query $number} result]} {
		$ud::output_cmd "PRIVMSG $chan :Error: $result"
		return
	}

	foreach line [ud::split_line 400 [dict get $result definition]] {
		if {[incr output] > $ud::max_lines} {
			$ud::output_cmd "PRIVMSG $chan :Output truncated. ${ud::url}?[http::formatQuery term $query defid [dict get $result number]]"
			break
		}
		$ud::output_cmd "PRIVMSG $chan :$line"
	}
}

proc ud::fetch {query number} {
	http::config -useragent $ud::client
	set page [expr {int(ceil($number / 7.0))}]
	set number [expr {$number - (($page - 1) * 7)}]

	set http_query [http::formatQuery term $query page $page]

	set token [http::geturl $ud::url -timeout 20000 -query $http_query]
	set data [http::data $token]
	set ncode [http::ncode $token]
	http::cleanup $token

	if {$ncode != 200} {
		error "HTTP fetch error. Code: $ncode"
	}

	set definitions [regexp -all -inline -- $ud::list_regexp $data]
	if {[llength $definitions] < $number} {
		error "[llength $definitions] definitions found."
	}

	return [ud::parse $query [lindex $definitions [expr {$number - 1}]]]
}

proc ud::parse {query raw_definition} {
	regexp $ud::def_regexp $raw_definition -> number definition
	set definition [htmlparse::mapEscapes $definition]
	set definition [regsub -all -- {<.*?>} $definition ""]
	set definition [regsub -all -- {\n+} $definition " "]
	set definition [string tolower $definition]
	return [list number $number definition "$query is $definition"]
}

# by fedex
proc ud::split_line {max str} {
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

putlog "slang.tcl loaded"
