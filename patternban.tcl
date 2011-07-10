#
# 10/07/2011
#

namespace eval patternban {
	variable filename "scripts/patternbans.txt"
	variable ban_reason "bye"

	# List of pattern bans. Each item in list has the syntax:
	# {channel} {host pattern} {words pattern}
	variable patternbans [list]

	bind msg o|- "!addpatternban"   ::patternban::add
	bind msg o|- "!listpatternbans" ::patternban::ls
	bind msg o|- "!delpatternban"   ::patternban::rm

	bind pubm -|- "*" ::patternban::match
}

# Return a list consisting of the 3 parts of a uhost: nick!ident@host
# Not used. Only part of match_mask.
proc ::patternban::split_uhost {uhost} {
	set nick_uhost [split $uhost !]
	set nick [lindex $nick_uhost 0]

	set ident_host [split [lindex $nick_uhost 1] @]

	set ident [lindex $ident_host 0]
	set host [lindex $ident_host 1]

	return [list $nick $ident $host]
}

# Return whether uhost matches the given uhost_mask
# Not used. Same as matchaddr?
proc ::patternban::match_mask {uhost_mask uhost} {
	set mask_split [::patternban::split_uhost $uhost_mask]
	set uhost_split [::patternban::split_uhost $uhost]
	# Nick portion
	if {[string match [lindex $mask_split 0] [lindex $uhost_split 0]]} {
		# Ident portion
		if {[string match [lindex $mask_split 1] [lindex $uhost_split 1]]} {
			if {[string match [lindex $mask_split 2] [lindex $uhost_split 2]]} {
				return 1
			}
		}
	}
	return 0
}

proc ::patternban::ban {chan nick uhost} {
	putlog "Trying to ban ${nick}!${uhost} on $chan."
	putserv "mode $chan +b [maskhost $uhost 3]"
	putserv "kick $chan $nick :$::patternban::ban_reason"
}

proc ::patternban::match {nick uhost hand chan text} {
	foreach pattern $::patternban::patternbans {
		set pattern_channel [lindex $pattern 0]
		set pattern_uhost [lindex $pattern 1]
		set pattern_pattern [lindex $pattern 2]
		if {$chan == $pattern_channel} {
			if {[string match *${pattern_pattern}* $text] && [matchaddr $pattern_uhost ${nick}!${uhost}]} {
				::patternban::ban $chan $nick $uhost
				return
			}
		}
	}
}

proc ::patternban::add {nick uhost hand text} {
	set text [split $text]
	if {[llength $text] != 3} {
		putserv "PRIVMSG $nick :Usage: !addpatternban <#channel> <nick!user@host pattern> <string pattern>"
		return
	}
	set channel [lindex $text 0]
	set uhost_pattern [lindex $text 1]
	set pattern [lindex $text 2]
	lappend ::patternban::patternbans [list $channel $uhost_pattern $pattern]
	::patternban::save_patternbans
	putserv "PRIVMSG $nick :Added pattern ban on $channel for $uhost_pattern containing $pattern."
}

proc ::patternban::ls {nick uhost hand text} {
	set count 0
	putserv "PRIVMSG $nick :[llength $::patternban::patternbans] patternbans."
	foreach pattern $::patternban::patternbans {
		putserv "PRIVMSG $nick :#${count}: $pattern"
		incr count
	}
}

proc ::patternban::rm {nick uhost hand text} {
	set text [split $text]
	if {[llength $text] != 1 || ![string is digit $text]} {
		putserv "PRIVMSG $nick :Usage: !delpatternban <#>"
		return
	}
	if {$text >= [llength $::patternban::patternbans]} {
		putserv "PRIVMSG $nick :Error: No such pattern ban."
		return
	}
	set ::patternban::patternbans [lreplace $::patternban::patternbans $text $text]
	putserv "PRIVMSG $nick :Pattern ban deleted."
	::patternban::save_patternbans
}

proc ::patternban::save_patternbans {} {
	if {[catch {open $::patternban::filename w} fid]} {
		return
	}
	puts -nonewline $fid $::patternban::patternbans
	close $fid
}

proc ::patternban::load_patternbans {} {
	if {[catch {open $::patternban::filename r} fid]} {
		return
	}
	set ::patternban::patternbans [read -nonewline $fid]
	close $fid
}

::patternban::load_patternbans
putlog "patternban.tcl loaded"
