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
# - Channel: .wz <location>

package require darksky
package require geonames

namespace eval ::wds {
	variable output_cmd putserv
}

proc ::wds::lookup {nick uhost hand chan argv} {
	if {![channel get $chan weather-darksky]} { return }

	set query [string trim $argv]
	if {$query == ""} {
		$::wds::output_cmd "PRIVMSG $chan :Usage: .wz <location>"
		return
	}

	set conf [::wds::load_config]

	set geonames [::geonames::new [dict get $conf geonames_username]]
	set geonames_result [::geonames::latlong $geonames $query]
	if {[dict exists $geonames_result error]} {
		$::wds::output_cmd "PRIVMSG $chan :Error looking up latitude/longitude: [dict get $geonames_result error]"
		return
	}

	set darksky [::darksky::new [dict get $conf darksky_key]]
	set darksky_result [::darksky::forecast $darksky \
		[dict get $geonames_result lat] [dict get $geonames_result lng]]
	if {[dict exists $darksky_result error]} {
		$::wds::output_cmd "PRIVMSG $chan :Error looking up forecast: [dict get $darksky_result error]"
		return
	}

	::wds::output $chan $geonames_result $darksky_result
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

	return $conf
}

proc ::wds::output {chan geonames darksky} {
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
	append output [expr [dict get $darksky humidity]*100]
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
	append output [expr [dict get $darksky cloudCover]*100]
	append output "%"
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
bind pub -|- .wz ::wds::lookup

putlog "weather-darksky.tcl (https://github.com/horgh/eggdrop-scripts/weather-darksky.tcl) loaded"
putlog "weather-darksky.tcl: Powered by Dark Sky (www.darksky.net)"
putlog "weather-darksky.tcl: Powered by GeoNames (www.geonames.org)"
