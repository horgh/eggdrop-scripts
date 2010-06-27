# Auto op script. Ops everyone in channels set +horgh_autoop
#
#
# Last change Sat Nov 15 17:18:29 PST 2008
#
# Created Thu Oct 23 18:32:36 PDT 2008
# By horgh

namespace eval horgh_autoop {
	variable output_cmd putserv

	setudef flag horgh_autoop
	bind join -|- * horgh_autoop::horgh_autoop
}

proc horgh_autoop::horgh_autoop {nick host hand chan} {
	if {![channel get $chan horgh_autoop]} { return }
	$horgh_autoop::output_cmd "MODE $chan +o $nick"
}

putlog "horgh_autoop.tcl loaded"
