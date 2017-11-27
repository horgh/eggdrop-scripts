# Provides binds to read Yahoo.com futures
#
# If you update this, update the one in
# https://github.com/horgh/irssi-tcl-scripts.
package require http

namespace eval ::latoc {
	variable output_cmd putserv

	variable user_agent "Lynx/2.8.5rel.1 libwww-FM/2.14 SSL-MM/1.4.1 OpenSSL/0.9.7e"

	variable list_regexp {<tr class="data-row.*?".*?</a></td></tr>}
	variable stock_regexp {<td class="data-col0.*>(.*)</a></td><td class="data-col1.*>(.*)</td><td class="data-col2.*>(.*)</td><td class="data-col3.*>(.*)</td><td class="data-col4.*>(.*)<!-- /react-text --></span></td><td class="data-col5.*>(.*)<!-- /react-text --></span></td><td class="data-col6.*>(.*)</td><td class="data-col7.*>(.*)</td><td class="data-col8.*"}

	variable url "https://finance.yahoo.com/commodities?ltr=1"

	bind pub -|- "!oil"    ::latoc::oil_handler
	bind pub -|- "!gold"   ::latoc::gold_handler
	bind pub -|- "!silver" ::latoc::silver_handler

	setudef flag latoc
}

proc ::latoc::fetch {chan} {
	::http::config -useragent $::latoc::user_agent
	set token [::http::geturl $::latoc::url -timeout 20000]

	set status [::http::status $token]
	if {$status != "ok"} {
		set http_error [::http::error $token]
		$::latoc::output_cmd "PRIVMSG $chan :HTTP error: $status: $http_error"
		::http::cleanup $token
		return
	}

	set ncode [::http::ncode $token]
	if {$ncode != 200} {
		set code [::http::code $token]
		$::latoc::output_cmd "PRIVMSG $chan :HTTP error: $ncode: $code"
		::http::cleanup $token
		return
	}

	set data [::http::data $token]
	::http::cleanup $token

	return $data
}

proc ::latoc::parse {data} {
	set lines []
	foreach stock [regexp -all -inline -- $::latoc::list_regexp $data] {
		regexp $::latoc::stock_regexp $stock -> symbol name price last change percent volume interest
		set direction none
		if {$change < 0} {
			set direction Down
		}
		if {$change > 0} {
			set direction Up
		}
		lappend lines [::latoc::format $name $price $last $direction $change $percent]
	}

	return $lines
}

proc ::latoc::output {chan lines symbol_pattern} {
	foreach line $lines {
		if {![regexp -- $symbol_pattern $line]} {
			continue
		}
		$::latoc::output_cmd "PRIVMSG $chan :$line"
	}
}

proc ::latoc::oil_handler {nick uhost hand chan argv} {
	if {![channel get $chan latoc]} { return }

	set data [::latoc::fetch $chan]
	set lines [::latoc::parse $data]
	::latoc::output $chan $lines {Crude Oil}
}

proc ::latoc::gold_handler {nick uhost hand chan argv} {
	if {![channel get $chan latoc]} { return }

	set data [::latoc::fetch $chan]
	set lines [::latoc::parse $data]
	::latoc::output $chan $lines {Gold}
}

proc ::latoc::silver_handler {nick uhost hand chan argv} {
	if {![channel get $chan latoc]} { return }

	set data [::latoc::fetch $chan]
	set lines [::latoc::parse $data]
	::latoc::output $chan $lines {Silver}
}

proc ::latoc::format {name price last direction change percent} {
	return "$name: \00310$price [::latoc::colour $direction $change] [::latoc::colour $direction $percent]\003 $last"
}

proc ::latoc::colour {direction value} {
	if {[string match "Down" $direction]} {
		return \00304$value\017
	}
	if {[string match "Up" $direction]} {
		return \00309$value\017
	}
	return $value
}

putlog "latoc.tcl loaded"
