#
# 22/02/2011
# by horgh
#
# Logs what is said/emoted in set channels in a given sqlite database
#
# Table:
#  id
#  channel
#  type (0 = msg)
#  time
#  nick
#  s (text)
#

package require sqlite3

namespace eval sqlite_log {
	variable db_file /home/irc/log.db
	variable channels [list #antix #idiotbox]

	bind pubm -|- * sqlite_log::pub
}

proc sqlite_log::init {} {
	db eval {drop table log}
	catch {db eval {create table log(id integer primary key, channel text, type integer, time text, nick text, s text)}} result
}

proc sqlite_log::pub {nick uhost hand chan text} {
	if {[lsearch -exact $sqlite_log::channels $chan] == -1} { return }
	db eval {INSERT INTO log VALUES(NULL, $chan, 0, datetime('now'), $nick, $text)}
}

sqlite3 db $sqlite_log::db_file
sqlite_log::init

putlog "sqlite_log.tcl loaded"
