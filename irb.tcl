#
# 0.1 - May 15 2010
#
# by horgh (www.summercat.com)
#
# A _VERY UNSAFE_ wrapper for irb <-> irc via eggdrop
#
# Setup:
# - make sure you set/check the 3 variables (channel, command char, irb path)
#
# Usage:
# - {command_char}reset to get a fresh irb session
#
# - any commands prefixed with command_char are sent to irb and the result is
#   posted to the channel
#   - e.g.
#     <@horgh> 'test
#     <@Yorick> Starting new irb session...
#     <@Yorick> => ArgumentError: wrong number of arguments
#     <@Yorick> =>     from (irb):1:in `test'
#     <@Yorick> =>     from (irb):1
#
# BUGS:
#  - since "=>" isn't shown from the open call for some reason (perhaps it goes
#    to stderr or something, i'm not sure), some results that print on same line
#    do not display nicely, such as:
#      '5.times { print "*" }
#      results in "=> *****5" whereas it should be "*****=> 5" from the prompt
#

namespace eval irb {
	# Settings

	# channel to respond to irb commands / send output
	set channel #YOUR_CHANNEL
	# system path to irb binary
	set irb {/usr/local/bin/irb}
	# prefix character for sending data to irb
	set command_char "'"

	#set output_cmd cd::putnow
	set output_cmd putserv

	# You shouldn't need to edit anything below here

	set irb_chan []
	# store commands entered here so we don't output them
	# they are deleted as they come up from reading irb output
	set cmd_cache []

	bind pubm -|- "*" irb::put
	bind pub -|- "${command_char}reset" irb::reset
	bind evnt -|- "prerestart" irb::end
	bind evnt -|- "prerehash" irb::end
}

proc irb::put {nick uhost hand chan argv} {
	if {$chan != $irb::channel} { return }
	if {[string index $argv 0] != $irb::command_char} { return}

	set cmd [string range $argv 1 end]
	if {$cmd == "reset" } { return }
	if {$cmd == ""} { return }

	if {$irb::irb_chan == []} {
		setup_irb
	}

	lappend irb::cmd_cache $cmd
	puts $irb::irb_chan $cmd
}

proc irb::reset {nick uhost hand chan argv} {
	$irb::output_cmd "PRIVMSG $irb::channel :Closing irb session."
	irb::end
}

proc irb::setup_irb {} {
	$irb::output_cmd "PRIVMSG $irb::channel :Starting new irb session..."
	set irb::irb_chan [open "|${irb::irb}" r+]
	fconfigure $irb::irb_chan -blocking 1 -buffering line
	# call irb::output when data to be read
	fileevent $irb::irb_chan readable irb::output
}

proc irb::output {} {
	set output [gets $irb::irb_chan]
	set output [string map {\t "    "} $output]
	
	# check if it is a command sent to irb rather than a result (to not print)
	set index [lsearch -exact $irb::cmd_cache $output]
	if {$index >= 0} {
		set irb::cmd_cache [lreplace $irb::cmd_cache $index $index]
	} else {
		$irb::output_cmd "PRIVMSG $irb::channel :=> $output"
	}
}

# We close channel before restart/rehash
proc irb::end {args} {
	close $irb::irb_chan
	set irb::irb_chan []
}

putlog "irb.tcl loaded"
