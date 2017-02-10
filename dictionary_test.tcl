#
# Unit tests for dictionary.tcl
#

# Dummy some eggdrop functions.
proc ::bind {a b c d} {}
proc ::setudef {a b} {}
proc ::putlog {s} {}

source dictionary.tcl

proc ::tests {} {
	puts "Running tests..."

	set success 1

	if {![::test_quotemeta]} {
		set success 0
	}

	if {![::test_string_contains_term]} {
		set success 0
	}

	if {![::test_is_addressing_bot]} {
		set success 0
	}

	if {$success} {
		puts "Success!"
	} else {
		puts "Failure."
		exit 1
	}
}

proc ::test_quotemeta {} {
	set tests [list \
		[dict create input hi! output hi\\!] \
		[dict create input hi output hi] \
		[dict create input hi*+ output hi\\*\\+] \
		[dict create input hi\{\}\\ output hi\\\{\\\}\\\\] \
	]

	set failed 0

	foreach test $tests {
		set output [::dictionary::quotemeta [dict get $test input]]
		if {$output != [dict get $test output]} {
			puts [format "FAILURE: quotemeta(%s) = %s, wanted %s" \
				[dict get $test input] $output [dict get $test output]]

			incr failed
		}
	}

	if {$failed != 0} {
		puts [format "quotemeta: %d/%d tests failed" $failed [llength $tests]]
	}

	return [expr $failed == 0]
}

proc ::test_string_contains_term {} {
	set tests [list \
		[dict create s "hi test hi" term "test" want 1] \
		[dict create s "hi testing hi" term "test" want 0] \
		[dict create s "hi test, hi" term "test" want 1] \
		[dict create s "hi test. hi" term "test" want 1] \
		[dict create s "test" term "test" want 1] \
		[dict create s "hi test" term "test" want 1] \
		[dict create s "test hi" term "test" want 1] \
		[dict create s "test hi" term "TEST" want 1] \
		[dict create s "TEST hi" term "test" want 1] \
	]

	set failed 0

	foreach test $tests {
		set s [dict get $test s]
		set term [dict get $test term]
		set want [dict get $test want]

		set output [::dictionary::string_contains_term $s $term]
		if {$output != $want} {
			puts [format "FAILURE: string_contains_term(\"%s\", \"%s\") = %d, wanted %d" \
				$s $term $output $want]

			incr failed
		}
	}

	if {$failed != 0} {
		puts [format "string_contains_term: %d/%d tests failed" $failed \
			[llength $tests]]
	}

	return [expr $failed == 0]
}

proc ::test_is_addressing_bot {} {
	set tests [list \
		[dict create line "bot: hi"    botnick "bot" want 1] \
		[dict create line "BOT: hi"    botnick "bot" want 1] \
		[dict create line "bot: hi"    botnick "BOT" want 1] \
		[dict create line "bot:hi"     botnick "BOT" want 1] \
		[dict create line "bot hi"     botnick "bot" want 0] \
		[dict create line "bot2: hi"   botnick "bot" want 0] \
		[dict create line ": hi"       botnick "bot" want 0] \
		[dict create line "hi bot: hi" botnick "bot" want 0] \
		[dict create line "bbot: hi"   botnick "bot" want 0] \
		[dict create line "botbot: hi" botnick "bot" want 0] \
	]

	set failed 0

	foreach test $tests {
		set line [dict get $test line]
		set botnick [dict get $test botnick]
		set want [dict get $test want]

		set output [::dictionary::is_addressing_bot $line $botnick]
		if {$output != $want} {
			puts [format "FAILURE: is_addressing_bot(\"%s\", \"%s\") = %d, wanted %d" \
				$s $line $botnick $want]

			incr failed
		}
	}

	if {$failed != 0} {
		puts [format "string_contains_term: %d/%d tests failed" $failed \
			[llength $tests]]
	}

	return [expr $failed == 0]
}

::tests
