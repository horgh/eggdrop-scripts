#
# 2011-02-04
#
# Fetch commits from a github repo and output to IRC
#
# Better way to do this is to use service hooks, but for those repos where
# one doesn't have admin access, this is an option.
#
# Reference: http://develop.github.com/p/commits.html
#

package require http
package require json

namespace eval github_watch {
	variable channel "#idiotbox"

	# every 1 minute
	bind time - "* * * * *" github_watch::update

	variable max_commits 5

	# Github user/repo to watch
	variable user "sveinfid"
	variable repo "Antix"
	variable branch "master"

	variable url "http://github.com/api/v2/json/commits/list/"

	variable state_file "scripts/github_watch.state"
	variable last_id

	variable timeout 10000

	bind evnt -|- "save" github_watch::write_state
}

proc github_watch::write_state {args} {
	set fid [open $github_watch::state_file w]
	puts $fid $github_watch::last_id
	close $fid
}

proc github_watch::read_state {} {
	if {[catch {open $github_watch::state_file r} fid]} {
		set github_watch::last_id nt
		return
	}
	set data [read -nonewline $fid]
	close $fid
	set raw [split $data \n]
	set github_watch::last_id [lindex $raw 0]
}

proc github_watch::output {commit} {
	set committer [dict get $commit committer]
	set committer_name [dict get $committer name]

	set msg [dict get $commit message]
	set url "http://github.com[dict get $commit url]"

	#putserv "PRIVMSG $github_watch::channel :${committer_name}: ${msg} - ${url}"
	putserv "PRIVMSG $github_watch::channel :\[\002${committer_name}\002\]: ${msg}"
}

proc github_watch::get_commits {} {
	# Fetch updates
	set token [http::geturl ${github_watch::url}${github_watch::user}/${github_watch::repo}/${github_watch::branch}]
	set data [http::data $token]
	set ncode [http::ncode $token]
	set status [http::status $token]
	http::cleanup $token

	if {$ncode != 200} {
		error "HTTP fetch failure: $ncode, $data"
	}

	set json_dict [json::json2dict $data]
	set commits_dict [lindex $json_dict 1]

	set commits [list]

	set old_last_id $github_watch::last_id
	# Take the first $max_commits or up to an id we have already seen and return
	for {set i 0} {$i < $github_watch::max_commits} {incr i} {
		set commit [lindex $commits_dict $i]

		if {[dict get $commit id] == $old_last_id} {
			break
		}
		if {$i == 0} {
			set github_watch::last_id [dict get $commit id]
		}

		lappend commits $commit
	}

	return [lreverse $commits]
}

proc github_watch::update {min hour day month year} {
	if {[catch {github_watch::get_commits} result]} {
		putlog "PRIVMSG $github_watch::channel :github watch: Error: $result"
		return
	}

	foreach commit $result {
		github_watch::output $commit
	}
}

github_watch::read_state
putlog "github_watch.tcl loaded"
