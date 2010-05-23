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
# Requires Tcl 8.5+
# Requires tcllib for json
#

package require http
package require json

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
	set result [google::decode_html $result]
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
	set output "$title @ $url"
	$google::output_cmd "PRIVMSG $chan :[google::decode_html $output]"
}


# Return results from API query of $url
proc google::api_fetch {terms url} {
	set query [http::formatQuery v "1.0" q $terms safe off]
	set headers [list Referer $google::api_referer]

	set token [http::geturl ${url}?${query} -headers $headers -method GET -binary 1]
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
proc google::api_handler {chan argv url} {
	if {[catch {google::api_validate $argv $url} results]} {
		$google::output_cmd "PRIVMSG $chan :$results"
		return
	}

	foreach result $results {
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

# From perpleXa's urbandictionary script
# Replaces html special chars with their hex equivalent
proc google::decode_html {content} {
	if {![string match *&* $content]} {
		return $content;
	}
	set escapes {
		&nbsp; \x20 &quot; \x22 &amp; \x26 &apos; \x27 &ndash; \x2D
		&lt; \x3C &gt; \x3E &tilde; \x7E &euro; \x80 &iexcl; \xA1
		&cent; \xA2 &pound; \xA3 &curren; \xA4 &yen; \xA5 &brvbar; \xA6
		&sect; \xA7 &uml; \xA8 &copy; \xA9 &ordf; \xAA &laquo; \xAB
		&not; \xAC &shy; \xAD &reg; \xAE &hibar; \xAF &deg; \xB0
		&plusmn; \xB1 &sup2; \xB2 &sup3; \xB3 &acute; \xB4 &micro; \xB5
		&para; \xB6 &middot; \xB7 &cedil; \xB8 &sup1; \xB9 &ordm; \xBA
		&raquo; \xBB &frac14; \xBC &frac12; \xBD &frac34; \xBE &iquest; \xBF
		&Agrave; \xC0 &Aacute; \xC1 &Acirc; \xC2 &Atilde; \xC3 &Auml; \xC4
		&Aring; \xC5 &AElig; \xC6 &Ccedil; \xC7 &Egrave; \xC8 &Eacute; \xC9
		&Ecirc; \xCA &Euml; \xCB &Igrave; \xCC &Iacute; \xCD &Icirc; \xCE
		&Iuml; \xCF &ETH; \xD0 &Ntilde; \xD1 &Ograve; \xD2 &Oacute; \xD3
		&Ocirc; \xD4 &Otilde; \xD5 &Ouml; \xD6 &times; \xD7 &Oslash; \xD8
		&Ugrave; \xD9 &Uacute; \xDA &Ucirc; \xDB &Uuml; \xDC &Yacute; \xDD
		&THORN; \xDE &szlig; \xDF &agrave; \xE0 &aacute; \xE1 &acirc; \xE2
		&atilde; \xE3 &auml; \xE4 &aring; \xE5 &aelig; \xE6 &ccedil; \xE7
		&egrave; \xE8 &eacute; \xE9 &ecirc; \xEA &euml; \xEB &igrave; \xEC
		&iacute; \xED &icirc; \xEE &iuml; \xEF &eth; \xF0 &ntilde; \xF1
		&ograve; \xF2 &oacute; \xF3 &ocirc; \xF4 &otilde; \xF5 &ouml; \xF6
		&divide; \xF7 &oslash; \xF8 &ugrave; \xF9 &uacute; \xFA &ucirc; \xFB
		&uuml; \xFC &yacute; \xFD &thorn; \xFE &yuml; \xFF
	};
	set content [string map $escapes $content];
	set content [string map [list "\]" "\\\]" "\[" "\\\[" "\$" "\\\$" "\\" "\\\\"] $content];
	regsub -all -- {&#([[:digit:]]{1,5});} $content {[format %c [string trimleft "\1" "0"]]} content;
	regsub -all -- {&#x([[:xdigit:]]{1,4});} $content {[format %c [scan "\1" %x]]} content;
	regsub -all -- {&#?[[:alnum:]]{2,7};} $content "?" content;
	return [subst $content];
}
