#
# June 26 2010
# by horgh
#

package provide isgd 0.1

package require http

namespace eval isgd {
	variable url http://is.gd/api.php
}

proc isgd::shorten {url} {
	set query [http::formatQuery longurl $url]
	set token [http::geturl ${isgd::url}?${query} -timeout 20000 -method GET]
	set data [http::data $token]
	set ncode [http::ncode $token]
	http::cleanup $token

	if {$ncode != 200} {
		error "HTTP error ($ncode): $data"
	}

	return $data
}
