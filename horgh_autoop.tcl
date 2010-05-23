# Auto op script. Ops everyone in channels set +horgh_autoop
#
#
# Last change Sat Nov 15 17:18:29 PST 2008
#
# Created Thu Oct 23 18:32:36 PDT 2008
# By horgh

setudef flag horgh_autoop

bind join -|- * horgh_autoop::horgh_autoop

namespace eval horgh_autoop {
}

proc horgh_autoop::horgh_autoop {nick host hand chan} {
	if {![channel get $chan horgh_autoop]} { return }
	if {[string match -nocase "GoodOne*" $nick]} { return }
	if {[string match -nocase "*.fr" $host]} { return }
	quote::putnow "MODE $chan +o $nick"
}

putlog "horgh_autoop.tcl loaded"
