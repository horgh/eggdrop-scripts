# to debug this
      #set junk [open "ig-debug.txt" w]
      #puts $junk $html
      #close $junk

package require http

bind pub -|- "!oil" latoc::oil_handler
#bind pub -|- "!gold" latoc::gold_handler
bind pub -|- "!c" latoc::commodity_handler
bind pub -|- "!silver" latoc::silver_handler
bind pub -|- "!url" latoc::url_handler

setudef flag latoc

namespace eval latoc {
	variable user_agent "Lynx/2.8.5rel.1 libwww-FM/2.14 SSL-MM/1.4.1 OpenSSL/0.9.7e"
	variable output_cmd putserv

	variable list_regexp {<tr><td class="first">.*?<td class="last">.*?</td></tr>}
	#variable stock_regexp {<a href="/q\?s=(.*?)">.*?<td class="second name">(.*?)</td><td><b><span id=".*?">(.*?)</span></b> <nobr><span .*?>(.*?)(?:</span>)??</nobr>.*?(?:alt="(.*?)">)?? <b style="color.*?;">(.*?)</b>.*?<b style="color.*?;"> \((.*?)\)</b>}
	variable stock_regexp {<a href="/q\?s=(.*?)">.*?<td class="second name">(.*?)</td>.*?<span id=".*?">(.*?)</span></b> <nobr><span id=".*?">(.*?)</span></nobr>.*?(?:alt="(.*?)">)?? <b style="color.*?;">(.*?)</b>.*?<b style="color.*?;"> \((.*?)\)</b>}

	variable commodities [list energy metals grains livestock softs]
	variable energy_futures "http://finance.yahoo.com/futures?t=energy"
	variable commodities_url "http://finance.yahoo.com/futures?t="
}

proc latoc::url_handler {nick uhost hand chan argv} {
	$latoc::output_cmd "PRIVMSG $chan :$latoc::commodities_url"
}

proc latoc::commodity_handler {nick uhost hand chan argv} {
	if {![channel get $chan latoc]} { return }
	if {[lsearch $latoc::commodities $argv] == -1} {
		$latoc::output_cmd "PRIVMSG $chan :Valid commodities are: $latoc::commodities"
		return
	}

	set token [http::geturl "${latoc::commodities_url}$argv" -timeout 60000]
	if {![string match "ok" [http::status $token]]} {
		$latoc::output_cmd "PRIVMSG $chan :Error."
		return
	}

# debug stuff
#	set html [http::data $token]
#	set junk [open "commodity-debug.txt" w]
#	puts $junk $html
#	close $junk

	foreach stock [regexp -all -inline -- $latoc::list_regexp [http::data $token]] {
		regexp $latoc::stock_regexp $stock -> symbol name price last direction change percent
		$latoc::output_cmd "PRIVMSG $chan :[latoc::format $name $price $last $direction $change $percent]"
	}
}

proc latoc::oil_handler {nick uhost hand chan argv} {
	if {![channel get $chan latoc]} { return }

	set token [http::geturl $latoc::energy_futures -timeout 60000]

# debug stuff
#	set html [http::data $token]
#	set junk [open "oil-debug.txt" w]
#	puts $junk $html
#	close $junk

	if {![string match "ok" [http::status $token]]} {
		$latoc::output_cmd "PRIVMSG $chan :Error."
		return
	}

	foreach stock [regexp -all -inline -- $latoc::list_regexp [http::data $token]] {
		regexp $latoc::stock_regexp $stock -> symbol name price last direction change percent
		$latoc::output_cmd "PRIVMSG $chan :[latoc::format $name $price $last $direction $change $percent]"
		break
	}
}

proc latoc::gold_handler {nick uhost hand chan argv} {
	if {![channel get $chan latoc]} { return }

	set token [http::geturl ${latoc::commodities_url}metals -timeout 60000]
	if {![string match "ok" [http::status $token]]} {
		$latoc::output_cmd "PRIVMSG $chan :Error."
		return
	}

	foreach stock [regexp -all -inline -- $latoc::list_regexp [http::data $token]] {
		regexp $latoc::stock_regexp $stock -> symbol name price last direction change percent
		if {[string match -nocase "*Gold*" $name]} {
			$latoc::output_cmd "PRIVMSG $chan :[latoc::format $name $price $last $direction $change $percent]"
		}
	}
}

proc latoc::silver_handler {nick uhost hand chan argv} {
	if {![channel get $chan latoc]} { return }

	set token [http::geturl ${latoc::commodities_url}metals -timeout 60000]
	if {![string match "ok" [http::status $token]]} {
		$latoc::output_cmd "PRIVMSG $chan :Error."
		return
	}

	foreach stock [regexp -all -inline -- $latoc::list_regexp [http::data $token]] {
		regexp $latoc::stock_regexp $stock -> symbol name price last direction change percent
		if {[string match -nocase "*Silver*" $name]} {
			$latoc::output_cmd "PRIVMSG $chan :[latoc::format $name $price $last $direction $change $percent]"
		}
	}
}

proc latoc::format {name price last direction change percent} {
# this cuts off the Jun 09 part from Crude Oil Jun 09
#	set name [lrange $name 0 [expr [llength $name]-3]]
	return "$name: \00310$price [latoc::colour $direction $change] [latoc::colour $direction $percent]\003 $last"
}

proc latoc::colour {direction value} {
	if {[string match "Down" $direction]} {
		return \00304-$value\017
	} elseif {[string match "Up" $direction]} {
		return \00309+$value\017
	} else {
		return $value
	}
}
