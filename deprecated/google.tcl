#
# 0.3 - ?
#  - switch from decode_html to htmlparse::mapEscape
#  - fix issue with encoding getting ascii
#  - add !g1 for one result
#  - strip remaining html from api result
#
# 0.2 - May 10 2010
#  - fix for garbled utf chars in api queries
#  - added +google channel flag to enable
#  - strip html from !convert as some formatting may be present
#  - fix decode_html to convert html utf to hex
#  - convert <sup></sup> to exponent
#
# 0.1 - Some time in April 2010
#  - Initial release
#
# Created Feb 28 2010
#
# License: Public domain
#
# Requires Tcl 8.5+
# Requires tcllib for json
#

package require http
package require json
package require htmlparse

namespace eval google {
	#variable output_cmd "cd::putnow"
	variable output_cmd "putserv"

	# Not enforced for API queries
	variable useragent "Lynx/2.8.8dev.2 libwww-FM/2.14 SSL-MM/1.4.1"

	variable convert_url "http://www.google.ca/search"
	variable convert_regexp {<table class=std>.*?<b>(.*?)</b>.*?</table>}

	variable api_url "http://ajax.googleapis.com/ajax/services/search/"

	variable api_referer "http://www.egghelp.org"

	bind pub	-|- "!g" google::search
	bind pub	-|- "!google" google::search
	bind pub	-|- "!g1" google::search1
	bind pub	-|- "!news" google::news
	bind pub	-|- "!images" google::images
	bind pub	-|- "!convert" google::convert

	setudef flag google
}

proc google::convert_fetch {terms} {
	http::config -useragent $google::useragent

	set query [http::formatQuery q $terms]
	set token [http::geturl ${google::convert_url}?${query}]
	set data [http::data $token]
	set ncode [http::ncode $token]
	http::cleanup $token

	# debug
	#set fid [open "g-debug.txt" w]
	#puts $fid $data
	#close $fid

	if {$ncode != 200} {
		error "HTTP query failed: $ncode"
	}

	return $data
}

proc google::convert_parse {html} {
	if {![regexp -- $google::convert_regexp $html -> result]} {
		error "Parse error or no result"
	}
	set result [htmlparse::mapEscapes $result]
	# change <sup>num</sup> to ^num (exponent)
	set result [regsub -all -- {<sup>(.*?)</sup>} $result {^\1}]
	# strip rest of html code
	return [regsub -all -- {<.*?>} $result ""]
}

# Query normal html for conversions
proc google::convert {nick uhost hand chan argv} {
	if {![channel get $chan google]} { return }

	if {[string length $argv] == 0} {
		$google::output_cmd "PRIVMSG $chan :Please provide a query."
		return
	}

	if {[catch {google::convert_fetch $argv} data]} {
		$google::output_cmd "PRIVMSG $chan :Error fetching results: $data."
		return
	}

	if {[catch {google::convert_parse $data} result]} {
		$google::output_cmd "PRIVMSG $chan :Error: $result."
		return
	}

	$google::output_cmd "PRIVMSG $chan :\002$result\002"
}

# Output for results from api query
proc google::output {chan url title content} {
	regsub -all -- {(?:<b>|</b>)} $title "\002" title
	regsub -all -- {<.*?>} $title "" title
	set output "$title @ $url"
	$google::output_cmd "PRIVMSG $chan :[htmlparse::mapEscapes $output]"
}

# Return results from API query of $url
proc google::api_fetch {terms url} {
	set query [http::formatQuery v "1.0" q $terms safe off]
	set headers [list Referer $google::api_referer]

	set token [http::geturl ${url}?${query} -headers $headers -method GET]
	set data [http::data $token]
	set ncode [http::ncode $token]
	http::cleanup $token

	# debug
	#set fid [open "g-debug.txt" w]
	#fconfigure $fid -translation binary -encoding binary
	#puts $fid $data
	#close $fid

	if {$ncode != 200} {
		error "HTTP query failed: $ncode"
	}

	return [json::json2dict $data]
}

# Validate input and then return list of results
proc google::api_validate {argv url} {
	if {[string length $argv] == 0} {
		error "Please supply search terms."
	}

	if {[catch {google::api_fetch $argv $url} data]} {
		error "Error fetching results: $data."
	}

	set response [dict get $data responseData]
	set results [dict get $response results]

	if {[llength $results] == 0} {
		error "No results."
	}

	return $results
}

# Query api
proc google::api_handler {chan argv url {num {}}} {
	if {[catch {google::api_validate $argv $url} results]} {
		$google::output_cmd "PRIVMSG $chan :$results"
		return
	}

	foreach result $results {
		if {$num != "" && [incr count] > $num} {
			return
		}
		dict with result {
			# $language holds lang in news results, doesn't exist in web results
			if {![info exists language] || $language == "en"} {
				google::output $chan $unescapedUrl $title $content
			}
		}
	}
}

# Regular API search
proc google::search {nick uhost hand chan argv} {
	if {![channel get $chan google]} { return }

	google::api_handler $chan $argv ${google::api_url}web
}

# Regular API search, 1 result
proc google::search1 {nick uhost hand chan argv} {
	if {![channel get $chan google]} { return }

	google::api_handler $chan $argv ${google::api_url}web 1
}

# News from API
proc google::news {nick uhost hand chan argv} {
	if {![channel get $chan google]} { return }

	google::api_handler $chan $argv ${google::api_url}news
}

# Images from API
proc google::images {nick uhost hand chan argv} {
	if {![channel get $chan google]} { return }

	google::api_handler $chan $argv ${google::api_url}images
}
