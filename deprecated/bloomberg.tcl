#
# 20/07/2011
#

package require http

namespace eval ::bloomberg {
	bind pub -|- !metals ::bloomberg::metals
	bind pub -|- !gold   ::bloomberg::gold
	bind pub -|- !silver ::bloomberg::silver
	bind pub -|- !oil    ::bloomberg::oil

	variable futures_url {http://www.bloomberg.com/markets/commodities/futures/}

	variable user_agent "Lynx/2.8.5rel.1 libwww-FM/2.14 SSL-MM/1.4.1 OpenSSL/0.9.7e"
	# ms
	variable http_timeout 60000

	setudef flag bloomberg
}

proc ::bloomberg::fetch_data {} {
	::http::config -useragent $::bloomberg::user_agent
	set token [::http::geturl $::bloomberg::futures_url -timeout $::bloomberg::http_timeout]
	set data [::http::data $token]
	set ncode [::http::ncode $token]
	::http::cleanup $token

	if {$ncode != 200} {
		error "HTTP error code $ncode $data"
	}
	return $data
}

# Returns a dict, each key name of commodity
# Each value for key is itself a dict with values
# name, value, updown, change, change_percent, datetime
proc ::bloomberg::parse_html {html} {
	# Get rid of everything before energy table
	regexp -- {<a class="nohov">(.*)} $html -> html

	set bulk_commodity_regexp {<tr.*?>.*?<td class="change value_.*?">.*?</tr>}
	set commodity_regexp {<td class="name">(.*?)</td>.*?<td class="value">(.*?)</td>.*?<td class="change value_(.*?)">(.*?)</td>.*?<td class="change value_.*?">(.*?)</td>.*?<td class="datetime">(.*?)</td>}

	set commodity_dict [dict create]
	foreach commodity_html [regexp -all -inline -- $bulk_commodity_regexp $html] {
		#puts "comm $commodity_html"
		regexp -- $commodity_regexp $commodity_html -> name value updown change change_percent datetime
		# Name can have excessive spacing
		set name [regsub -all -- {\s+} $name " "]

		#puts "name $name value $value updown $updown change $change change_percent $change_percent datetime $datetime"
		dict append commodity_dict $name [list name $name value $value updown $updown change $change change_percent $change_percent datetime $datetime]
	}
	return $commodity_dict
}

# Get commodities with names matching the names in list_of_commodities
proc ::bloomberg::get_futures {list_of_commodities} {
	set raw_data [::bloomberg::fetch_data]
	set futures_dict [::bloomberg::parse_html $raw_data]

	set wanted_commodities [list]
	foreach commodity_key [dict keys $futures_dict] {
		foreach wanted_commodity $list_of_commodities {
			if {[regexp -nocase -- $wanted_commodity $commodity_key]} {
				lappend wanted_commodities [dict get $futures_dict $commodity_key]
			}
		}
	}
	return $wanted_commodities
}

proc ::bloomberg::colour {updown str} {
	if {[regexp -nocase -- {up} $updown]} {
		return \00309+$str\017\003
	} elseif {[regexp -nocase -- {down} $updown]} {
		return \00304$str\017\003
	} else {
		return $str\003
	}
}

proc ::bloomberg::output_commodity {chan commodity_dict} {
	set colour []
	set name [dict get $commodity_dict name]
	set value [dict get $commodity_dict value]
	set change [::bloomberg::colour [dict get $commodity_dict updown] "[dict get $commodity_dict change] [dict get $commodity_dict change_percent]"]
	set datetime [dict get $commodity_dict datetime]

	putserv "PRIVMSG $chan :$name: \00310$value $change $datetime"
}

proc ::bloomberg::oil {nick uhost hand chan argv} {
	if {![channel get $chan bloomberg]} { return }

	set commodities [::bloomberg::get_futures [list crude]]
	foreach commodity_dict $commodities {
		::bloomberg::output_commodity $chan $commodity_dict
	}
}

proc ::bloomberg::metals {nick uhost hand chan argv} {
	if {![channel get $chan bloomberg]} { return }

	set commodities [::bloomberg::get_futures [list copper gold silver]]
	foreach commodity_dict $commodities {
		::bloomberg::output_commodity $chan $commodity_dict
	}
}

proc ::bloomberg::gold {nick uhost hand chan argv} {
	if {![channel get $chan bloomberg]} { return }

	set commodities [::bloomberg::get_futures [list gold]]
	foreach commodity_dict $commodities {
		::bloomberg::output_commodity $chan $commodity_dict
	}
}

proc ::bloomberg::silver {nick uhost hand chan argv} {
	if {![channel get $chan bloomberg]} { return }

	set commodities [::bloomberg::get_futures [list silver]]
	foreach commodity_dict $commodities {
		::bloomberg::output_commodity $chan $commodity_dict
	}
}

putlog "bloomberg.tcl loaded"
