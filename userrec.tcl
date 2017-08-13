# This script provides minimal Eggdrop user record manipulation in a channel.
#
# Primarily I'm interested in letting people know if the bot recognizes them.

namespace eval ::ur {}

proc ::ur::whoami {nick uhost hand chan argv} {
	if {$hand == "*"} {
		putserv "PRIVMSG $chan :I don't know you!"
		return
	}
	putserv "PRIVMSG $chan :You're $hand"
}

setudef flag userrec
bind pub -|- .whoami ::ur::whoami

putlog "userrec.tcl (https://github.com/horgh/eggdrop-scripts/userrec.tcl) loaded"
