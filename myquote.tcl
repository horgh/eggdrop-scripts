#
# 16/08/2010
# by horgh
#
# MySQL quote script
#
# Setup:
#  The table must be called "quote" and have the following schema:
#  CREATE TABLE quote (
#   	qid SMALLINT UNSIGNED NOT NULL AUTO_INCREMENT,
#   	uid SMALLINT UNSIGNED NOT NULL,
#   	quote TEXT NOT NULL,
#   	PRIMARY KEY (qid)
#  );
#  Other keys are possible but not required
#
# aq (addquote) usage:
#  - \n starts a new line for the quote
#  - e.g.: aq <user> hi there!\n<user2> hey
#    becomes the quote:
#     <user> hi there
#     <user2> hey
#

package require mysqltcl

namespace eval myquote {
	variable output_cmd putserv

	# MySQL settings
	variable host localhost
	variable user quote
	variable pass quote
	variable db quote

	# mysql connection handler
	variable conn []

	# search results stored in this dict
	variable results []

	bind pub -|- latest     myquote::latest
	bind pub -|- quotestats myquote::stats
	bind pub -|- quote      myquote::quote
	bind pub -|- aq         myquote::addquote
	bind pub m|- delquote   myquote::delquote

	setudef flag quote
}

proc myquote::connect {} {
	# If connection not initialised or has disconnected
	if {![mysql::state $myquote::conn -numeric] || ![mysql::ping $myquote::conn]} {
		set myquote::conn [mysql::connect -host $myquote::host -user $myquote::user -password $myquote::pass -db $myquote::db]
		putlog "Connecting to db..."
	}
}

# fetch a single quote row with given statement
proc myquote::fetch_single {stmt} {
	mysql::sel $myquote::conn $stmt
	mysql::map $myquote::conn {qid quote} {
		set q [list qid $qid quote $quote]
	}
	return $q
}

proc myquote::fetch_search {terms} {
	putlog "Retrieving new quotes for $terms..."
	set terms [mysql::escape $myquote::conn $terms]
	set stmt "SELECT qid, quote FROM quote WHERE quote LIKE \"%${terms}%\" LIMIT 20"
	set count [mysql::sel $myquote::conn $stmt]
	if {$count <= 0} {
		return []
	}
	mysql::map $myquote::conn {qid quote} {
		lappend quotes [list qid $qid quote $quote]
	}
	return $quotes
}

proc myquote::stats {nick host hand chan argv} {
	if {![channel get $chan quote]} { return }
	myquote::connect
	set stmt "SELECT COUNT(qid) FROM quote"
	mysql::sel $myquote::conn $stmt
	mysql::map $myquote::conn {c} {
		set count $c
	}
	$myquote::output_cmd "PRIVMSG $chan :There are $count quotes in the database."
}

proc myquote::latest {nick host hand chan argv} {
	if {![channel get $chan quote]} { return }
	myquote::connect
	set stmt "SELECT qid, quote FROM quote ORDER BY qid DESC LIMIT 1"
	myquote::output $chan [myquote::fetch_single $stmt]
}

proc myquote::random {} {
	set stmt "SELECT qid, quote FROM quote ORDER BY RAND() LIMIT 1"
	return [myquote::fetch_single $stmt]
}

proc myquote::quote_by_id {id} {
	set stmt "SELECT qid, quote FROM quote WHERE qid = ${id}"
	return [myquote::fetch_single $stmt]
}

proc myquote::quote {nick host hand chan argv} {
	if {![channel get $chan quote]} { return }
	myquote::connect
	if {$argv == ""} {
		myquote::output $chan [myquote::random]
	} elseif {[string is integer $argv]} {
		myquote::output $chan [myquote::quote_by_id $argv]
	} else {
		myquote::output $chan {*}[myquote::search $argv]
	}
}

proc myquote::search {terms} {
	set terms [regsub -all -- {\*} $terms "%"]
	if {![dict exists $myquote::results $terms]} {
		dict set myquote::results $terms [myquote::fetch_search $terms]
	}

	# Extract one quote from results
	set quotes [dict get $myquote::results $terms]
	set quote [lindex $quotes 0]
	set quotes [lreplace $quotes 0 0]

	# Remove key if no quotes after removal of one, else update quotes
	if {![llength $quotes]} {
		dict unset myquote::results $terms
	} else {
		dict set myquote::results $terms $quotes
	}
	return [list $quote [llength $quotes]]
}

proc myquote::addquote {nick host hand chan argv} {
	if {![channel get $chan quote]} { return }
	if {$argv == ""} {
		$myquote::output_cmd "PRIVMSG $chan :Usage: aq <text...>"
		return
	}
	myquote::connect

	set argv [regsub -all -- {\\n} $argv \n]
	set quote [mysql::escape $myquote::conn $argv]
	set stmt "INSERT INTO quote (uid, quote) VALUES(1, \"${quote}\")"
	set count [mysql::exec $myquote::conn $stmt]
	$myquote::output_cmd "PRIVMSG $chan :${count} quote added."
}

proc myquote::delquote {nick host hand chan argv} {
	if {$argv == "" || ![string is integer $argv]} {
		$myquote::output_cmd "PRIVMSG $chan :Usage: delquote <#>"
		return
	}
	myquote::connect
	set stmt "DELETE FROM quote WHERE qid = ${argv}"
	set count [mysql::exec $myquote::conn $stmt]
	$myquote::output_cmd "PRIVMSG $chan :#${argv} deleted. ($count quotes affected.)"
}

# quote is dict of form {qid ID quote TEXT}
proc myquote::output {chan quote {left {}}} {
	if {$quote == ""} {
		$myquote::output_cmd "PRIVMSG $chan :No quotes found."
		return
	}
	set qid [dict get $quote qid]
	set text [dict get $quote quote]
	set head "Quote #\002$qid\002"
	if {$left ne ""} {
		set head "${head} ($left left)"
	}
	$myquote::output_cmd "PRIVMSG $chan :$head"
	foreach l [split $text \n] {
		$myquote::output_cmd "PRIVMSG $chan : $l"
	}
}

myquote::connect
putlog "myquote.tcl loaded"
