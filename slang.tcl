#
# slang.tcl - June 24 2010
# by horgh
#
# Requires Tcl 8.5+ and tcllib
#
# Made with heavy inspiration from perpleXa's urbandict script!
#
# Must .chanset #channel +ud
#
# Uses is.gd to shorten long definition URL if isgd.tcl package present
#

package require htmlparse
package require http

namespace eval ::ud {
	# set this to !ud or whatever you want
	variable trigger "slang"

	# maximum lines to output
	variable max_lines 1

	# approximate characters per line
	variable line_length 400

	# show truncated message / url if more than one line
	variable show_truncate 1

	variable output_cmd "putserv"

	variable client "Mozilla/5.0 (compatible; Y!J; for robot study; keyoshid)"
	variable url http://www.urbandictionary.com/define.php
	variable url_random http://www.urbandictionary.com/random.php

	# regex to find the word 
	# if we have an inexact match, then we may have the word wrapped in <a/>.
	variable word_regexp {<div class='word' data-defid='.*?'>\s*?(?:<a class="index".*?<\/a>\s*?)?<span>\s*(?:<a href=\"[^>]+\">)?(.*?)(?:</a>)?\s*?</span>}
	variable list_regexp {<div class='text'.*? id='entry_.*?'>.*?</div>}
	variable def_regexp {id='entry_(.*?)'>.*?<div class="definition">(.*?)</div>}

	setudef flag ud
	bind pub -|- $::ud::trigger ::ud::handler

	# 0 if isgd package is present
	variable isgd_disabled [catch {package require isgd}]
}

proc ::ud::handler {nick uhost hand chan argv} {
	if {![channel get $chan ud]} { return }
	set argv [string trim $argv]
	set argv [split $argv]
	if {[string is digit [lindex $argv 0]]} {
		set number [lindex $argv 0]
		set query [join [lrange $argv 1 end]]
	} else {
		set query [join $argv]
		set number 1
	}
	set query [string trim $query]

	if {[llength $argv] == 1 && [string is digit [lindex $argv 0]]} {
		$::ud::output_cmd "PRIVMSG $chan :Usage: $::ud::trigger \[#\] <query> (or just $::ud::trigger for random definition)"
		return
	}

	if {$query == ""} {
		if {[catch {::ud::get_random} result]} {
			$::ud::output_cmd "PRIVMSG $chan :Error: $result"
			return
		}
		::ud::output $chan $result
	} else {
		if {[catch {::ud::get_def $query $number} result]} {
			$::ud::output_cmd "PRIVMSG $chan :Error: $result"
			return
		}
		::ud::output $chan $result
	}
}

proc ::ud::output {chan def_dict} {
	set output 0
	foreach line [::ud::split_line $::ud::line_length [dict get $def_dict definition]] {
		if {[incr output] > $::ud::max_lines} {
			if {$::ud::show_truncate} {
				$::ud::output_cmd "PRIVMSG $chan :Output truncated. [::ud::def_url $def_dict]"
			}
			break
		}
		$::ud::output_cmd "PRIVMSG $chan :$line"
	}
}

proc ::ud::get_random {} {
	set result [::ud::http_fetch $::ud::url_random ""]
	set word [dict get $result word]
	set defs_html [dict get $result definitions]

	if {[llength $defs_html] < 1} {
		error "Failure finding random definition."
	}

	return [::ud::parse $word [lindex $defs_html 0]]
}

proc ::ud::get_def {query number} {
	set page [expr {int(ceil($number / 7.0))}]
	set number [expr {$number - (($page - 1) * 7)}]

	set http_query [http::formatQuery term $query page $page]

	set result [::ud::http_fetch $::ud::url $http_query]
	set word [dict get $result word]
	set defs_html [dict get $result definitions]

	if {[llength $defs_html] < $number} {
		error "[llength $defs_html] definitions found."
	}

	return [::ud::parse $word [lindex $defs_html [expr {$number - 1}]]]
}

proc ::ud::http_fetch {url http_query} {
	http::config -useragent $::ud::client

	set token [http::geturl $url -timeout 20000 -query $http_query]
	set data [http::data $token]
	set ncode [http::ncode $token]
	set meta [http::meta $token]
	http::cleanup $token

	# Follow redirects
	if {[regexp -- {30[01237]} $ncode]} {
		set new_url [dict get $meta Location]
		return [::ud::http_fetch $new_url $http_query]
	}

	if {$ncode != 200} {
		error "HTTP fetch error. Code: $ncode"
	}

	# pull out the word.
	if {![regexp -- $::ud::word_regexp $data -> word]} {
		error "Failed to parse word"
	}
	set word [string trim $word]
	set definitions [regexp -all -inline -- $::ud::list_regexp $data]
	if {![llength $definitions]} {
		error "No definitions found"
	}
	return [list word $word definitions $definitions]
}

proc ::ud::parse {word raw_definition} {
	if {![regexp $::ud::def_regexp $raw_definition -> number definition]} {
		error "Could not parse HTML"
	}
	set definition [htmlparse::mapEscapes $definition]
	set definition [regsub -all -- {<.*?>} $definition ""]
	set definition [regsub -all -- {\n+} $definition " "]
	set definition [string tolower $definition]
	return [list number $number word $word definition "$word is $definition"]
}

proc ::ud::def_url {def_dict} {
	set word [dict get $def_dict word]
	set number [dict get $def_dict number]
	set raw_url ${::ud::url}?[http::formatQuery term $word defid $number]
	if {$::ud::isgd_disabled} {
		return $raw_url
	} else {
		if {[catch {isgd::shorten $raw_url} shortened]} {
			return "$raw_url (is.gd error)"
		} else {
			return $shortened
		}
	}
}

# by fedex
proc ::ud::split_line {max str} {
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
