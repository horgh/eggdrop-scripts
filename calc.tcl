# created by fedex

bind pub - !calc safe_calc
bind pub - .calc safe_calc
setudef flag calc

proc is_op {str} {
	return [expr [lsearch {{ } . + - * / ( ) %} $str] != -1]
}

proc safe_calc {nick uhost hand chan str} {
	if {![channel get $chan calc]} { return }

	foreach char [split $str {}] {
		if {![is_op $char] && ![string is integer $char]} {
			putserv "PRIVMSG $chan :$nick: Invalid expression for calc."
			return
		}
	}

	# make all values floating point
	set str [regsub -all -- {((?:\d+)?\.?\d+)} $str {[expr {\1*1.0}]}]
	set str [subst $str]

	if {[catch {expr $str} out]} {
		putserv "PRIVMSG $chan :$nick: Invalid equation."
		return
	} else {
		putserv "PRIVMSG $chan :$str = $out"
	}
}
