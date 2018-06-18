# A weather script that uses www.darksky.net as its source. Its output is based
# on incith-weather.tcl.
#
# It relies on two packages:
# - https://github.com/horgh/geonames-tcl (for looking up latitude/longitude)
# - https://github.com/horgh/darksky-tcl (for looking up weather)
#
# Setup:
# - Create a weather-darksky.conf and put it in your Eggdrop root directory.
#   See weather-darksky.conf.sample for the format.
# - You'll need to source both of those .tcl files in your bot prior to this
#   one.
# - Partyline: .chanset #channel +weather-darksky
# - Channel: .wz <location> for current weather or .wzf <location> for a
#   forecast

package require darksky
package require geonames

namespace eval ::wds {
	variable output_cmd putserv
	variable geonames_cache [dict create]
}

proc ::wds::lookup_current {nick uhost hand chan argv} {
	if {![channel get $chan weather-darksky]} { return }

	set query [::wds::get_query $nick $uhost $argv]
	if {$query == ""} {
		$::wds::output_cmd "PRIVMSG $chan :Usage: .wz <location>"
		return
	}

	set data [::wds::get_data $chan $query]
	if {![dict exists $data geonames] || ![dict exists $data darksky]} {
		return
	}
	set geonames [dict get $data geonames]
	set darksky [dict get $data darksky]

	::wds::output_current $chan $geonames $darksky
}

proc ::wds::lookup_forecast {nick uhost hand chan argv} {
	if {![channel get $chan weather-darksky]} { return }

	set query [::wds::get_query $nick $uhost $argv]
	if {$query == ""} {
		$::wds::output_cmd "PRIVMSG $chan :Usage: .wzf <location>"
		return
	}

	set data [::wds::get_data $chan $query]
	if {![dict exists $data geonames] || ![dict exists $data darksky]} {
		return
	}
	set geonames [dict get $data geonames]
	set darksky [dict get $data darksky]

	::wds::output_forecast $chan $geonames $darksky
}

# Retrieve the query to look up. If none is given, return the last one we used.
# If one was given, remember it.
#
# We only remember it if there is a matching user record. In theory we could add
# users but in order to do that we must have a handle to assign them, and what
# to use is unclear. I suppose we could generate something random.
proc ::wds::get_query {nick uhost argv} {
	set query [string trim $argv]
	set query [string tolower $query]
	if {$query != ""} {
		::wds::set_default_location $nick $uhost $query
		return $query
	}

	return [::wds::get_default_location $nick $uhost]
}

proc ::wds::set_default_location {nick uhost query} {
	set hand [finduser $nick!$uhost]
	if {$hand == "*"} {
		return
	}

	setuser $hand XTRA weather-darksky $query
}

proc ::wds::get_default_location {nick uhost} {
	set hand [finduser $nick!$uhost]
	if {$hand == "*"} {
		return ""
	}

	set location [getuser $hand XTRA weather-darksky]
	return $location
}

proc ::wds::get_data {chan query} {
	set conf [::wds::load_config]

	set geonames_result [::wds::get_lat_long $conf $query]
	if {[dict exists $geonames_result error]} {
		$::wds::output_cmd "PRIVMSG $chan :Error looking up latitude/longitude: [dict get $geonames_result error]"
		return [dict create]
	}

	set darksky [::darksky::new [dict get $conf darksky_key]]
	set darksky_result [::darksky::forecast $darksky \
		[dict get $geonames_result lat] [dict get $geonames_result lng]]
	if {[dict exists $darksky_result error]} {
		$::wds::output_cmd "PRIVMSG $chan :Error looking up forecast: [dict get $darksky_result error]"
		return [dict create]
	}

	return [dict create geonames $geonames_result darksky $darksky_result]
}

proc ::wds::get_lat_long {conf query} {
	if {[dict exists $::wds::geonames_cache $query]} {
		return [dict get $::wds::geonames_cache $query]
	}

	set geonames [::geonames::new [dict get $conf geonames_username]]

	set geonames_result {}

	# If the user gave us what looks like a US zip code, use the postal code
	# search API rather than the text search API. The text search API gives
	# unreliable results using zip codes alone.
	if {[regexp -- {\A[0-9]{5}\Z} $query]} {
		set geonames_result [::geonames::postalcode_latlong $geonames $query US]
	} else {
		set geonames_result [::geonames::search_latlong $geonames $query]
	}

	if {![dict exists $geonames_result error]} {
		dict set ::wds::geonames_cache $query $geonames_result
		::wds::save_cache $conf
	}

	return $geonames_result
}

proc ::wds::save_cache {conf} {
	set fh [open [dict get $conf geonames_cache_file] w]
	puts -nonewline $fh $::wds::geonames_cache
	close $fh
}

proc ::wds::load_cache {} {
	set conf [::wds::load_config]

	if {![file exists [dict get $conf geonames_cache_file]]} {
		set ::wds::geonames_cache [dict create]
		return
	}

	set fh [open [dict get $conf geonames_cache_file]]
	set ::wds::geonames_cache [read -nonewline $fh]
	close $fh
}

proc ::wds::load_config {} {
	set fh [open weather-darksky.conf]
	set contents [read -nonewline $fh]
	close $fh

	set lines [split $contents \n]
	set conf [dict create]
	foreach line $lines {
		set line [string trim $line]
		if {$line == ""} {
			continue
		}

		set pieces [split $line "="]
		if {[llength $pieces] != 2} {
			putlog "weather-darksky.tcl: Invalid configuration line: $line"
			continue
		}

		set key [string trim [lindex $pieces 0]]
		set value [string trim [lindex $pieces 1]]
		if {$key == ""} {
			putlog "weather-darksky.tcl: Invalid key on line: $line"
			continue
		}
		if {$value == ""} {
			putlog "weather-darksky.tcl: Invalid value on line: $line"
			continue
		}

		dict set conf $key $value
	}

	if {![dict exists $conf geonames_username]} {
		error "no geonames_username set"
	}
	if {![dict exists $conf darksky_key]} {
		error "no darksky_key set"
	}
	if {![dict exists $conf geonames_cache_file ]} {
		error "no geonames_cache_file set"
	}

	return $conf
}

proc ::wds::output_current {chan geonames darksky} {
	set output ""
	append output [dict get $geonames name]
	append output ", "
	append output [dict get $geonames countryName]

	append output " ("
	append output [::wds::format_decimal [dict get $darksky latitude]]
	append output "°N/"
	append output [::wds::format_decimal [dict get $darksky longitude]]
	append output "°W)"

	append output " \002Conditions\002: "
	append output [dict get $darksky summary]
	$::wds::output_cmd "PRIVMSG $chan :$output"

	set output ""
	append output "\002Temperature\002: "
	append output [dict get $darksky temperature]
	append output "°C"

	append output " ("
	append output [::wds::celsius_to_fahrenheit [dict get $darksky temperature]]
	append output "°F"
	append output ")"

	append output " \002Humidity\002: "
	append output [::wds::format_decimal [expr [dict get $darksky humidity]*100]]
	append output "%"

	append output " \002Pressure\002: "
	append output [dict get $darksky pressure]
	append output " hPa"
	$::wds::output_cmd "PRIVMSG $chan :$output"

	set output ""
	append output "\002Wind\002: "
	append output [dict get $darksky windSpeed]
	append output "m/s"

	append output " \002Clouds\002: "
	append output [::wds::format_decimal \
		[expr [dict get $darksky cloudCover]*100] \
	]
	append output "%"
	$::wds::output_cmd "PRIVMSG $chan :$output"
}

proc ::wds::output_forecast {chan geonames darksky} {
	set output ""
	append output [dict get $geonames name]
	append output ", "
	append output [dict get $geonames countryName]

	append output " ("
	append output [::wds::format_decimal [dict get $darksky latitude]]
	append output "°N/"
	append output [::wds::format_decimal [dict get $darksky longitude]]
	append output "°W) "
	$::wds::output_cmd "PRIVMSG $chan :$output"

	set output ""
	set count 0
	foreach forecast [dict get $darksky forecast] {
		if {$count == 5} {
			break
		}
		if {[dict get $forecast time] < [clock seconds]} {
			continue
		}
		if {$output != ""} {
			append output " "
		}
		set day [clock format [dict get $forecast time] -format "%A"]
		append output "\002$day\002: "
		append output [dict get $forecast summary]
		append output " "

		append output [dict get $forecast temperatureMax]
		append output "/"
		append output [dict get $forecast temperatureMin]
		append output "°C"

		append output " ("
		append output [::wds::celsius_to_fahrenheit \
			[dict get $forecast temperatureMax] \
		]
		append output "/"
		append output [::wds::celsius_to_fahrenheit \
			[dict get $forecast temperatureMin] \
		]
		append output "°F"
		append output ")"
		incr count
	}
	$::wds::output_cmd "PRIVMSG $chan :$output"
}

proc ::wds::celsius_to_fahrenheit {celsius} {
	set fahrenheit [expr $celsius*9.0/5.0+32.0]
	return [::wds::format_decimal $fahrenheit]
}

proc ::wds::format_decimal {number} {
	return [format "%.2f" $number]
}

setudef flag weather-darksky
bind pub -|- .wz ::wds::lookup_current
bind pub -|- .wzf ::wds::lookup_forecast
::wds::load_cache

putlog "weather-darksky.tcl (https://github.com/horgh/eggdrop-scripts) loaded"
putlog "weather-darksky.tcl: Powered by Dark Sky (www.darksky.net)"
putlog "weather-darksky.tcl: Powered by GeoNames (www.geonames.org)"
