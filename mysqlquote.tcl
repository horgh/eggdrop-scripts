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

namespace eval sqlquote {
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

	bind pub -|- latest     sqlquote::latest
	bind pub -|- quotestats sqlquote::stats
	bind pub -|- quote      sqlquote::quote
	bind pub -|- aq         sqlquote::addquote
	bind pub m|- delquote   sqlquote::delquote

	setudef flag quote
}

proc sqlquote::connect {} {
	# If connection not initialised or has disconnected
	if {![mysql::state $sqlquote::conn -numeric] || ![mysql::ping $sqlquote::conn]} {
		set sqlquote::conn [mysql::connect -host $sqlquote::host -user $sqlquote::user -password $sqlquote::pass -db $sqlquote::db]
		putlog "Connecting to db..."
	}
}

# fetch a single quote row with given statement
proc sqlquote::fetch_single {stmt} {
	mysql::sel $sqlquote::conn $stmt
	mysql::map $sqlquote::conn {qid quote} {
		set q [list qid $qid quote $quote]
	}
	return $q
}

proc sqlquote::fetch_search {terms} {
	putlog "Retrieving new quotes for $terms..."
	set terms [mysql::escape $sqlquote::conn $terms]
	set stmt "SELECT qid, quote FROM quote WHERE quote LIKE \"%${terms}%\" LIMIT 20"
	set count [mysql::sel $sqlquote::conn $stmt]
	if {$count <= 0} {
		return []
	}
	mysql::map $sqlquote::conn {qid quote} {
		lappend quotes [list qid $qid quote $quote]
	}
	return $quotes
}

proc sqlquote::stats {nick host hand chan argv} {
	if {![channel get $chan quote]} { return }
	sqlquote::connect
	set stmt "SELECT COUNT(qid) FROM quote"
	mysql::sel $sqlquote::conn $stmt
	mysql::map $sqlquote::conn {c} {
		set count $c
	}
	$sqlquote::output_cmd "PRIVMSG $chan :There are $count quotes in the database."
}

proc sqlquote::latest {nick host hand chan argv} {
	if {![channel get $chan quote]} { return }
	sqlquote::connect
	set stmt "SELECT qid, quote FROM quote ORDER BY qid DESC LIMIT 1"
	sqlquote::output $chan [sqlquote::fetch_single $stmt]
}

proc sqlquote::random {} {
	set stmt "SELECT qid, quote FROM quote ORDER BY RAND() LIMIT 1"
	return [sqlquote::fetch_single $stmt]
}

proc sqlquote::quote_by_id {id} {
	set stmt "SELECT qid, quote FROM quote WHERE qid = ${id}"
	return [sqlquote::fetch_single $stmt]
}

proc sqlquote::quote {nick host hand chan argv} {
	if {![channel get $chan quote]} { return }
	sqlquote::connect
	if {$argv == ""} {
		sqlquote::output $chan [sqlquote::random]
	} elseif {[string is integer $argv]} {
		sqlquote::output $chan [sqlquote::quote_by_id $argv]
	} else {
		sqlquote::output $chan {*}[sqlquote::search $argv]
	}
}

proc sqlquote::search {terms} {
	set terms [regsub -all -- {\*} $terms "%"]
	if {![dict exists $sqlquote::results $terms]} {
		dict set sqlquote::results $terms [sqlquote::fetch_search $terms]
	}

	# Extract one quote from results
	set quotes [dict get $sqlquote::results $terms]
	set quote [lindex $quotes 0]
	set quotes [lreplace $quotes 0 0]

	# Remove key if no quotes after removal of one, else update quotes
	if {![llength $quotes]} {
		dict unset sqlquote::results $terms
	} else {
		dict set sqlquote::results $terms $quotes
	}
	return [list $quote [llength $quotes]]
}

proc sqlquote::addquote {nick host hand chan argv} {
	if {![channel get $chan quote]} { return }
	if {$argv == ""} {
		$sqlquote::output_cmd "PRIVMSG $chan :Usage: aq <text...>"
		return
	}
	sqlquote::connect

	set argv [regsub -all -- {\\n} $argv \n]
	set quote [mysql::escape $sqlquote::conn $argv]
	set stmt "INSERT INTO quote (uid, quote) VALUES(1, \"${quote}\")"
	set count [mysql::exec $sqlquote::conn $stmt]
	$sqlquote::output_cmd "PRIVMSG $chan :${count} quote added."
}

proc sqlquote::delquote {nick host hand chan argv} {
	if {$argv == "" || ![string is integer $argv]} {
		$sqlquote::output_cmd "PRIVMSG $chan :Usage: delquote <#>"
		return
	}
	sqlquote::connect
	set stmt "DELETE FROM quote WHERE qid = ${argv}"
	set count [mysql::exec $sqlquote::conn $stmt]
	$sqlquote::output_cmd "PRIVMSG $chan :#${argv} deleted. ($count quotes affected.)"
}

# quote is dict of form {qid ID quote TEXT}
proc sqlquote::output {chan quote {left {}}} {
	if {$quote == ""} {
		$sqlquote::output_cmd "PRIVMSG $chan :No quotes found."
		return
	}
	set qid [dict get $quote qid]
	set text [dict get $quote quote]
	set head "Quote #\002$qid\002"
	if {$left ne ""} {
		set head "${head} ($left left)"
	}
	$sqlquote::output_cmd "PRIVMSG $chan :$head"
	foreach l [split $text \n] {
		$sqlquote::output_cmd "PRIVMSG $chan : $l"
	}
}

sqlquote::connect
putlog "sqlquote.tcl loaded"
