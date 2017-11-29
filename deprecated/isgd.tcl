#
# June 26 2010
# by horgh
#

package provide isgd 0.1

package require http
package require tls
::http::register https 443 [list ::tls::socket -ssl2 0 -ssl3 0 -tls1 1]

namespace eval ::isgd {
	variable url https://is.gd/create.php
}

proc ::isgd::shorten {url} {
	set query [::http::formatQuery format simple url $url]
	set token [::http::geturl ${::isgd::url}?${query} -timeout 20000 -method GET]
	set data [::http::data $token]
	set ncode [::http::ncode $token]
	::http::cleanup $token

	if {$ncode != 200} {
		error "HTTP error ($ncode): $data"
	}

	return $data
}
