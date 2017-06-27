#
# edited Jun 27 2017 for https by genewitch
#
# Mar 30 2010
# by horgh
#
# Requires Tcl 8.5+ and tcllib
#
# Wikipedia.org fetcher
#
# To enable you must .chanset #channel +wiki
#
# Tests: Whole number (list of possible interpretations)
#

package require http
package require htmlparse
package require tls
::http::register https 443 ::tls::socket


namespace eval wiki {
	variable max_lines 1
	variable max_chars 400
	variable output_cmd "putserv"
	variable url "https://en.wikipedia.org/wiki/"

	bind pub -|- "!w" wiki::search
	bind pub -|- "!wiki" wiki::search

#	variable parse_regexp {(<table class.*?<p>.*?</p>.*?</table>)??.*?<p>(.*?)</p>\n<table id="toc"}
	variable parse_regexp {(?:</table>)?.*?<p>(.*)((</ul>)|(</p>)).*?((<table id="toc")|(<h2>)|(<table id="disambigbox"))}

	setudef flag wiki
}


proc wiki::fetch {term {url {}}} {
	if {$url != ""} {
		set token [http::geturl $url -timeout 10000]
	} else {
		set query [http::formatQuery [regsub -all -- {\s} $term "_"]]
		set token [http::geturl ${wiki::url}${query} -timeout 10000]
	}
	set data [http::data $token]
	set ncode [http::ncode $token]
	set meta [http::meta $token]
	upvar #0 $token state
	set fetched_url $state(url)
	http::cleanup $token

	# debug
	putlog "Fetch! term: $term url: $url fetched: $fetched_url"
	set fid [open "w-debug.txt" w]
	puts $fid $data
	close $fid

	# Follow redirects
	if {[regexp -- {^3\d{2}$} $ncode]} {
		return [wiki::fetch $term [dict get $meta Location]]
	}

	if {$ncode != 200} {
		error "HTTP query failed ($ncode): $data: $meta"
	}

	# If page returns list of results, choose the first one and fetch that
	#if {[regexp -- {<p>.*?((may refer to:)|(in one of the following senses:))</p>} $data]} {
	#	regexp -- {<ul>.*?<li>.*? title="(.*?)">.*?</li>} $data -> new_query
	#	return [wiki::fetch $new_query]
	#}

	if {![regexp -- $wiki::parse_regexp $data -> out]} {
		error "Parse error"
	}

	return [list url $fetched_url result [wiki::sanitise $out]]
}

proc wiki::sanitise {raw} {
	set raw [htmlparse::mapEscapes $raw]
	# Remove pronunciation stuff
	set raw [regsub -- {<span.*? class="IPA">.*?</span>} $raw ""]
	# Remove some help links
	set raw [regsub -- {<small class="metadata">.*?</small>} $raw ""]

	set raw [regsub -all -- {<(.*?)>} $raw ""]
	set raw [regsub -all -- {\[.*?\]} $raw ""]
	set raw [regsub -all -- {\n} $raw " "]
	return $raw
}

proc wiki::search {nick uhost hand chan argv} {
	if {![channel get $chan wiki]} { return }
	if {[string length $argv] == 0} {
		$wiki::output_cmd "PRIVMSG $chan :Please provide a term."
		return
	}

	set argv [string trim $argv]
	# Upper case first character
	set argv [string toupper [string index $argv 0]][string range $argv 1 end]

	if {[catch {wiki::fetch $argv} data]} {
		$wiki::output_cmd "PRIVMSG $chan :Error: $data"
		return
	}

	foreach line [wiki::split_line $wiki::max_chars [dict get $data result]] {
		if {[incr count] > $wiki::max_lines} {
			$wiki::output_cmd "PRIVMSG $chan :Output truncuated. [dict get $data url]"
			break
		}
		$wiki::output_cmd "PRIVMSG $chan :$line"
	}
}

# by fedex
proc wiki::split_line {max str} {
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

putlog "wiki.tcl loaded"
