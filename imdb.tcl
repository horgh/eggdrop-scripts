###############################################################################
##     This iMDB.tcl requires Eggdrop1.6.0 or higher                         ##
##                  (c) 2003 by B0unTy                                       ##
##                                                                           ##
##  changed by OV2                                                           ##
##  05.01.2010                                                               ##
##    *fixed remaining bugs with imdb changes                                ##
##                                                                           ##
##  02.01.2010                                                               ##
##    *modified for imdb page changes                                        ##
##                                                                           ##
##  16.09.2008                                                               ##
##    *modified for new imdb page                                            ##
##                                                                           ##
##  25.05.2008                                                               ##
##    *plot works again                                                      ##
##                                                                           ##
##  19.05.2008                                                               ##
##    *fixed the non-working cookies (cert, soundmix ...)                    ##
##    * "|" characters in cookies are displayed again                        ##
##                                                                           ##
##  21.09.2007                                                               ##
##    *multiline color/underline/bold were broken                            ##
##    +added single-line cast (%castline)                                    ##
##    +added the remaining information from imdb (color, cert, etc...)       ##
##                                                                           ##
##  17.07.2007                                                               ##
##    *fix for the exact title matching                                      ##
##    *exact name matches are no longer confused with exact title matches    ##
##                                                                           ##
##  27.06.2007                                                               ##
##    *works with new imdb search page                                       ##
##    *%uline works again                                                    ##
##                                                                           ##
##  09.04.2007:                                                              ##
##    *fixed director/s writer/s                                             ##
##    +added support for plot keywords                                       ##
##    +added support for user comment line                                   ##
##                                                                           ##
##  28.02.2007:                                                              ##
##    *ratings work again                                                    ##
##    *director and writing credits work again                               ##
##                                                                           ##
##  25.02.2007:                                                              ##
##    *fixed some bugs of the previous changes (thanks to rosc2112)          ##
##                                                                           ##
##  24.02.2007:                                                              ##
##    *bold/underline/color in front of the multiline cast will now be       ##
##     applied to each of the cast lines                                     ##
##    *the | character is now used to declare sections in the announce line  ##
##     if any variable in a section is not found on the imdb page, the       ##
##     corresponding section will not be displayed in the output             ##
##     (see the default announce line for an example)                        ##
##                                                                           ##
##  22.02.2007:                                                              ##
##    *incorporated some code from rosc2112's version                        ##
##    *some small fixes                                                      ##
##                                                                           ##
##  20.02.2007:                                                              ##
##    *changed regexp queries to accomodate the new imdb layout              ##
##    *cleaned up the unneccesary post-regexp code                           ##
##                                                                           ##
##  14.05.2006:                                                              ##
##    *fixed plot outline not showing completely if it included links        ##
##      (thanks to darkwing for finding the bug)                             ##
##    +added support for awards (thanks to rosc2112)                         ##
##    +added support for the cast list (be careful with the limit)           ##
##    +added support for writing credits                                     ##
##                                                                           ##
##  21.01.2006:                                                              ##
##    *fixed problem with irregular search-result pages from imdb            ##
##                                                                           ##
##  31.08.2005:                                                              ##
##    *changed search result priority again:                                 ##
##      1. popular match where the title=search string                       ##
##      2. exact matches                                                     ##
##      3. first title on page                                               ##
##    *fixed missig warn_msg var                                             ##
##                                                                           ##
##  until 24.06.2005:                                                        ##
##    *works with new IMDB                                                   ##
##    *works with (hopefully) all search results (popular/exact/partial)     ##
##    +added timeouts (20secs)                                               ##
##    +added bottom 100 support                                              ##
##    +added rating bar from chilla's imdb-script                            ##
##    +added flood control                                                   ##
##    *small speedup (if your output does not include %screens or %budget    ##
##    *changed proc name to improve compatibility with other scripts         ##
##    *changed search result priority to {exact->first displayed}            ##
##                                                                           ##
###############################################################################
##                                                                           ##
## INSTALL:                                                                  ##
## ========                                                                  ##
##   1- Copy iMDB.tcl in your dir scripts/                                   ##
##   2- Add iMDB.tcl in your eggdrop.conf:                                   ##
##        source scripts/imdb.tcl                                            ##
##                                                                           ##
##   For each channel you want users to use !imdb cmd                        ##
##   Just type in partyline: .chanset #channel +imdb                         ##
##                                                                           ##
###############################################################################
# COOKIES ARE :
# =============
# TITLE             = %title               |    BOLD           = %bold
# URL               = %url                 |    UNDERLINE      = %uline
# DIRECTOR          = %name                |    COLORS         = %color#,#
# GENRE             = %genre               |    NEW LINE       = \n
# PLOT OUTLINE      = %plot                |-----------------------------
# RATING            = %rating              |    !! to reset color code !!
# RATING_BAR        = %rbar                |    !! use %color w/o args !!
# VOTES             = %votes               |
# RUNTIME           = %time (numbers only) |    "|" declares a section
# AWARDS            = %awards              |    if any cookie in a section
# BUDGET            = %budget              |    is empty the whole section
# SCREENS           = %screens             |    is removed from the output
# TAGLINE           = %tagline             |    (end section with "|")
# MPAA              = %mpaa                |
# COUNTRY           = %country             |
# LANGUAGE          = %language            |
# SOUND MIX         = %soundmix            |
# TOP 250           = %top250              |
# CAST LINES        = %castmline           |
# CAST SNGLELINE    = %castline            |
# WRITING CREDITS   = %wcredits            |
# PLOT KEYWORDS     = %keywords            |
# COMMENT LINE      = %comment             |
# RELEASE DATE      = %reldate             |
# MOVIE COLOR       = %mcolor              |
# ASPECT RATIO      = %aspect              |
# CERTIFICATION     = %cert                |
# LOCATIONS         = %locations           |
# COMPANY           = %company             |
#
# RANDOMIZING OUTPUT :
# ====================
# Exemple:
#  set random(IMDBIRC-0)       "IMDB info for %bold%title%bold Directed by %name"
#  set random(IMDBIRC-1)       "IMDB info for %title Directed by %bold%name%bold"
#  set random(IMDBIRC-2)       "IMDB info for %title Directed by %name"
# TYPE --------^   ^
#       ID --------^
#
#  set announce(IMDBIRC) "random 3"
# TYPE ---------^        ^    ^
#       RANDOM ----------^    ^
#           # OF IDS ---------^
#
# exemple random announces:
# set announce(IMDBIRC) "random 3"
# set random(IMDBIRC-0) "IMDB info for %bold%title%bold Directed by %name -> rated %uline%rating%uline (%votes votes) - genre: %genre - runtime: %time mins >> URL: %uline%url%uline >> Budget: %budget >> Screens: (USA) %screens"
# set random(IMDBIRC-1) "TITLE: %bold%title%bold - DIRECTOR: %name - RATE: %rating by %votes users - GENRE: %genre - RUNTIME: %time mins - URL: %url - BUDGET: %budget - SCREENS: (USA) %screens"
# set random(IMDBIRC-2) "%bold%title%bold - %url\n%boldDirected by:%bold %name\n%boldGenre:%bold %genre\n%boldTagline:%bold %tagline\n%boldSynopsis:%bold %plot\n%boldRating:%bold %rating (%votes votes) top 250:%bold%top250%bold\n%boldMPAA:%bold %mpaa\n%boldRuntime:%bold %time mins.

# example normal announce:
#
set announce(IMDBIRC) "%bold%title%bold - %url\n|Genre: %genre|\n|Synopsis: %plot|\n|Rating: %rating (%votes votes) %rbar| |%color3%top250%color|\n|Awards: %awards|"
#set announce(IMDBIRC) "%bold%title%bold |\[%time mins - %mcolor\]| - %url\n|Genre: %genre|\n|Tagline: %tagline|\n|Synopsis: %plot|\n|Rating: %rating (%votes votes) %rbar| |%color3%top250%color|\n|Awards: %awards|"
#set announce(IMDBIRC) "%bold%title%bold - %url\n|%boldGenre:%bold %genre|\n|Plot Keywords: %keywords|\n|Tagline: %tagline|\n|Synopsis: %plot|\n|Rating: %rating (%votes votes) %rbar| |%color3%top250%color|\n|Comment: %comment|\n|Awards: %awards|\n|Runtime: %time mins.|"
#set announce(IMDBIRC) "%bold%title%bold - %url\n|%boldGenre:%bold %genre|\n|Director: %name|\n|Writers: %wcredits|\n|Cast: %castline|\n|Country: %country|\n|Language: %language|\n|Color: %mcolor|\n|Plot Keywords: %keywords|\n|Tagline: %tagline|\n|Synopsis: %plot|\n|Rating: %rating (%votes votes) %rbar| |%color3%top250%color|\n|Locations: %locations|\n|Comment: %comment|\n|Awards: %awards|\n|Runtime: %time mins.|\n|Cert: %cert|\n|Budget: %budget|\n|Screens: %screens|"


#trigger command in channel
set trigger "!imdb"

#rating bar color
#bracket
set barcol1 "14"
#stars
set barcol2 "7"
#cast count to return on multiline and single line (0 means no limit)
set cast_linelimit "5"

#http connection timeout (milliseconds)
set imdb_timeout "25000"

#flood-control
set queue_enabled 1
#max requests
set queue_size 5
#per ? seconds
set queue_time 120

# for a channel !imdb request
# set to 1 = all results will be sent publicly to the channel
# set to 0 = all results will be sent as private notice
set pub_or_not 1

# use or not the imdb debugger (1=enable debug  0=disable debug)
set IMDB_DEBUG 0

# set IMDB_ALTERNATIVE 0 = use the internal tcl http 2.3 package
# set IMDB_ALTERNATIVE 1 = use the external curl 6.0+
set IMDB_ALTERNATIVE 0

# set here the location path where find curl 6.0+
set binary(CURL) "/path/to/curl"
# note for windrop: use normal slashes, e.g. C:/path/to/curl.exe

#################################################################
# DO NOT MODIFY BELOW HERE UNLESS YOU KNOW WHAT YOU ARE DOING!  #
#################################################################
if { $IMDB_ALTERNATIVE == 0 } { package require http 2.3 }
package require htmlparse
setudef flag imdb

bind pub -|- $trigger imdb_proc

set instance 0
set warn_msg 0


proc channel_check_imdb { chan } {
    foreach setting [channel info $chan] {
        if {[regexp -- {^[\+-]} $setting]} {
            if {![string compare "+imdb" $setting]} {
                set permission 1
                break
            } else {
                set permission 0
            }
        }
    }
    return $permission
}

proc replacevar {strin what withwhat} {
    set output $strin
    set replacement $withwhat
    set cutpos 0
    while { [string first $what $output] != -1 } {
        set cutstart [expr [string first $what $output] - 1]
        set cutstop  [expr $cutstart + [string length $what] + 1]
        set output [string range $output 0 $cutstart]$replacement[string range $output $cutstop end]
    }
    return $output
}

proc findnth {strin what count} {
     set ret 0
     for {set x 0} {$x < $count} {incr x} {
         set ret [string first $what $strin [expr $ret + 1]]
     }
     return $ret
}

proc imdb_proc { nick uhost handle chan arg } {
    global cast_linelimit instance queue_size queue_time queue_enabled imdb_timeout barcol1 barcol2 IMDB_DEBUG pub_or_not announce random warn_msg trigger binary IMDB_ALTERNATIVE
    # channel_check permission
    set permission_result [channel_check_imdb $chan]
    if {$IMDB_DEBUG == 1} { putlog "IMDB_DEBUG permission_result == $permission_result" }
    if {$IMDB_DEBUG == 1} { putlog "IMDB_DEBUG instance == $instance" }
    if { $permission_result == 0} { return }
    # public or private
    if {$pub_or_not == 1 } { set toput "PRIVMSG $chan" } else { set toput "NOTICE $nick" }
    if {$IMDB_DEBUG == 1} { putlog "IMDB_DEBUG toput_result == $toput" }
    # if no arg passed, show help
    if {$arg == ""} {
        if { $IMDB_ALTERNATIVE == 0 } { set using "Http 2.3+" } else { set using "Curl 6.0+" }
        if {$IMDB_DEBUG == 1} { putlog "IMDB_DEBUG no arg passed, show help" }
        putserv "$toput :IMDb info script \002v05.01.2010\002 using \002$using\002"
        putserv "$toput :\002Syntax: $trigger <movie title>\002 example: $trigger Beautiful Mind"
        return
    }

    #flood-control
    if { $queue_enabled == 1 } {
       #flooded?
       if { $instance >= $queue_size } {
          if {$IMDB_DEBUG == 1} { putlog "IMDB_DEBUG flood detected" }
          if { $warn_msg == 0 } {
             set warn_msg 1
             putquick "$toput :Flood-Control: Request for \"$arg\" from user \"$nick\" will not be answered."
             putquick "$toput :Flood-Control: Maximum of $queue_size requests every $queue_time seconds."
             utimer 120 wmsg
          }
          return
       }
       incr instance
       if { $IMDB_DEBUG == 1 } { putlog "IMDB_DEBUG new instance == $instance" }
       utimer [set queue_time] decr_inst
    }

    # initial search
    set imdburl "http://www.imdb.com"
    set imdbsearchurl "http://akas.imdb.com/find?tt=on;nm=on;mx=5;"
    set searchString [string map {\  %20 & %26 , %2C} $arg]
    if {$IMDB_DEBUG == 1} { putlog "IMDB_DEBUG searchString: \"$searchString\"" }
    if { $IMDB_ALTERNATIVE == 0 } {
        set page [::http::config -useragent "MSIE 6.0"]
        if {$IMDB_DEBUG == 1} { putlog "IMDB_DEBUG ${imdbsearchurl}q=$searchString" }
        if [catch {set page [::http::geturl ${imdbsearchurl}q=$searchString -timeout $imdb_timeout]} error] {
            putserv "$toput :Error retrieving URL... try again later."
            ::http::Finish $page
            return
        }
        if { [::http::status $page] == "timeout" } {
            putserv "$toput :\002Connection to imdb.com timed out while doing initial search.\002"
            ::http::Finish $page
            return
        }
        set html [::http::data $page]
        ::http::Finish $page
    } else {
        catch { exec $binary(CURL) "${imdbsearchurl}q=$searchString" } html
    }
    #if redirect necessary (search page), find first link and redirect
    if { ([regexp {<title>IMDb.*Search} $html] == 1) } {
        if {$IMDB_DEBUG == 1} { putlog "IMDB_DEBUG redirect 1" }
        set ttcode "0000001"
        set start "0"
        set temp $html

        #dealing with different search results
        set hit 0
        if { [regexp -indices {Popular Titles} $temp tstart] } {
           if {$IMDB_DEBUG == 1} { putlog "IMDB_DEBUG found popular titles" }
           set temp2 [string range $temp [lindex $tstart 1] end]
           regexp {1\..*?<a.*?>(.*?)</a>} $temp2 dummy title
           if {$IMDB_DEBUG == 1} { putlog "IMDB_DEBUG compare $title == $arg" }
           if { [string equal -nocase $title $arg] } {
              if {$IMDB_DEBUG == 1} { putlog "IMDB_DEBUG equals - displaying first popular match" }
              set temp $temp2
              set hit 1
           } else {
              if {$IMDB_DEBUG == 1} { putlog "IMDB_DEBUG not equal - searching for exact match" }
           }

        }
        if { $hit == 0 } {
           if { [regexp -indices {Titles \(Exact Matches\)} $temp start] } {
              if {$IMDB_DEBUG == 1} { putlog "IMDB_DEBUG displaying exact match" }
           } elseif { [regexp -indices {Titles} $temp start] } {
              if {$IMDB_DEBUG == 1} { putlog "IMDB_DEBUG no exact match - displaying first title on page" }
           } else {
                putserv "$toput :No useful results."
                if {$IMDB_DEBUG == 1} { putlog "IMDB_DEBUG no titles results found" }
                return
           }
           set temp [string range $temp [lindex $start 1] end]
        }

        #searching for first ttcode
        if [regexp {/title/tt[0-9]+} $temp ttcode] {
           set pos [string last / $ttcode] ; incr pos
           set ttcode [string range $ttcode $pos end]
        }
        # for bogus ttcode
        if { $ttcode == "0000001" } {
            putserv "$toput :No no no! I can't find that!"
            if {$IMDB_DEBUG == 1} { putlog "IMDB_DEBUG bogus ttcode" }
            return
        }
        set newurl "$imdburl/title/$ttcode/"
        if {$IMDB_DEBUG == 1} { putlog "IMDB_DEBUG redirect 1 = $newurl" }
        # get the page redirected to
        unset html
        if { $IMDB_ALTERNATIVE == 0 } {
            set page [::http::config -useragent "MSIE 6.0"]
            set page [::http::geturl $newurl -timeout $imdb_timeout]
            if [catch {set page [::http::geturl $newurl -timeout $imdb_timeout]} error] {
                putserv "$toput :Error retrieving URL... try again later."
                ::http::Finish $page
                return
	        }
            if {[::http::status $page]=="timeout"} {
                putserv "$toput :\002Connection to imdb.com timed out.\002"
                ::http::Finish $page
                return
            }
            set html [::http::data $page]
            ::http::Finish $page
        } else {
            catch { exec $binary(CURL) "$newurl" } html
        }
    # if no redirect necessary (only one match in meta), then go there
    } else {
        set location ""
        if {$IMDB_DEBUG == 1} { putlog "IMDB_DEBUG redirect 0" }
        if { $IMDB_ALTERNATIVE == 0 } {
            upvar 0 $page oldpage
            regexp {title/tt[0-9]+/} $oldpage(meta) location
        } else {
            set result [catch { exec $binary(CURL) -i "${imdbsearchurl}q=$searchString" } oldpage]
            putlog $oldpage
            regexp {title/tt[0-9]+/} $oldpage location
        }
        if {$IMDB_DEBUG == 1} { putlog "IMDB_DEBUG redirect 0 Location == $location" }
        set newurl "$imdburl/$location"
        if {$IMDB_DEBUG == 1} { putlog "IMDB_DEBUG redirect 0 = $newurl" }
        if { $location != "" } {
            if { $IMDB_ALTERNATIVE == 0 } {
                unset html
                set page [::http::config -useragent "MSIE 6.0"]
                if [catch {set page [::http::geturl $newurl -timeout $imdb_timeout]} error] {
                    putserv "$toput :Error retrieving URL... try again later."
                    ::http::Finish $page
                    return
                }
                if {[::http::status $page]=="timeout"} {
                    putserv "$toput :\002Connection to imdb.com timed out.\002"
                    ::http::Finish $page
                    return
                }
                set html [::http::data $page]
                ::http::Finish $page
            } else {
                unset html
                catch { exec $binary(CURL) "$newurl" } html
            }
        } else { 
            putserv "$toput :Error in search mechanics - you probably need a newer version." 
            return 
        } 

    }
    # for bogus searches
    if {[string length $newurl] == 0} {
        putserv "$toput :No no no! I can't find that!"
        if {$IMDB_DEBUG == 1} { putlog "IMDB_DEBUG bogus searches" }
        return
    }
    # decide on output
    if { ! [string compare [lindex $announce(IMDBIRC) 0] "random"] && [string is alnum -strict [lindex $announce(IMDBIRC) 1]] == 1 } {
        set output $random(IMDBIRC\-[rand [lindex $announce(IMDBIRC) 1]])
    } else {
        set output $announce(IMDBIRC)
    }
    # collect output
    set title "N/A" ; set name "N/A" ; set genre "N/A" ; set tagline "N/A"
    set plot "N/A" ; set rating "N/A" ; set votes "N/A" ; set mpaa "N/A"
    set runtime "N/A" ; set budget "N/A" ; set screens "N/A" ; set country "N/A"
    set language "N/A" ; set soundmix "N/A" ; set top250 "top/bottom:N/A"; set awards "N/A"
    set rating_bar ""; set cast_multiline "N/A"; set wcredits "N/A"; set keywords "N/A"
    set comment "N/A"; set reldate "N/A"; set cast_line "N/A"
    set movie_color "N/A"; set aspect_ratio "N/A"; set cert "N/A"
    set film_locations "N/A"; set company "N/A"
    ## get title
    if [regexp {<title>[^<]+} $html title] {
        set pos [expr [string last > $title] + 1]
        set title [string range $title $pos end]
        set title [htmlparse::mapEscapes $title]
    }
    if {$IMDB_DEBUG == 1} { putlog "IMDB_DEBUG title == $title" }
    ## get director
    if [regexp {<h5>Director.*?</h5>(.*?)</div>} $html dummy name] {
        regsub -all {\n[ ]*} $name {} name
        set name [string map {"&#38;<br/>" "& " "<br/>" ", " "more" ""} $name]
        regsub -all {<[^>]+>} $name {} name
        set name [string trim $name]
        regsub -all {,$} $name {} name
        set name [htmlparse::mapEscapes $name]
    }
    if {$IMDB_DEBUG == 1} { putlog "IMDB_DEBUG director == $name" }
    ## get writing credits
    if [regexp {<h5>Writer.*?</h5>(.*?)</div>} $html dummy wcredits] {
        regsub -all {\n[ ]*} $wcredits {} wcredits
        set wcredits [string map {"more" "" "<br/>&nbsp;" "" "&#38;<br/>" "& " "&#x26;<br/>" "& " "<br/>" ", "} $wcredits]
        regsub -all {<[^>]+>} $wcredits {} wcredits
        set wcredits [string trim $wcredits]
        regsub -all {,$} $wcredits {} wcredits
        set wcredits [htmlparse::mapEscapes $wcredits]
    }
    if {$IMDB_DEBUG == 1} { putlog "IMDB_DEBUG writer == $wcredits" }
    # release date 
    if {[regexp {<h5>Release Date:</h5>(.*?)</div>} $html dummy reldate]} {
        regsub -all {<[^\>]*>} $reldate {} reldate
        set reldate [string map {"more" "" \n "" &amp; " & "} $reldate]
        set reldate [string trim $reldate]
        set reldate [htmlparse::mapEscapes $reldate]
    }
    if {$IMDB_DEBUG == 1} { putlog "IMDB_DEBUG release date == $reldate" }
    ## get genre
    if [regexp {<h5>Genre:</h5>(.*?)</div>} $html dummy genre] {
        set genre [string map {"more" ""} $genre]
        regsub -all {<[^\>]*>} $genre {} genre
        set genre [string map {"|" "||" } $genre]
        set genre [string trim $genre]
        regsub {\(.*\)} $genre {} genre
				set genre [htmlparse::mapEscapes $genre]
    }
    if {$IMDB_DEBUG == 1} { putlog "IMDB_DEBUG genre == $genre" }
    ## get tagline
    if [regexp {<h5>Tagline:</h5>(.*?)</div>} $html dummy tagline] {
        set tagline [string map {"more" "" } $tagline]
        regsub -all {<[^\>]*>} $tagline {} tagline
        set tagline [string trim $tagline]
        set tagline [htmlparse::mapEscapes $tagline]
    }
    if {$IMDB_DEBUG == 1} { putlog "IMDB_DEBUG tagline == $tagline" }
    ## get plot outline
    if { [regexp {<h5>Plot:</h5>(.*?)</div>} $html dummy plot] || [regexp {<h5>Plot Summary:</h5>(.*?)</div>} $html dummy plot] } {
        set plot [string map {"more" "" "(view trailer)" "" "full summary" "" "add synopsis" "" "full synopsis (warning! may contain spoilers)" "" "full synopsis" "" " | " ""} $plot]
        regsub -all {<[^\>]*>} $plot {} plot
        set plot [string trim $plot]
        set plot [htmlparse::mapEscapes $plot]
    }
    if {$IMDB_DEBUG == 1} { putlog "IMDB_DEBUG plot == $plot" }
    ## get plot keywords
    if [regexp {<h5>Plot Keywords:</h5>(.*?)</div>} $html dummy keywords] {
       set keywords [string map {"more" "" \n ""} $keywords]
       regsub -all {<[^\>]*>} $keywords {} keywords
       set keywords [string map {"|" "||"} $keywords]
       set keywords [string trim $keywords]
       set keywords [htmlparse::mapEscapes $keywords]
    }
    if {$IMDB_DEBUG == 1} { putlog "IMDB_DEBUG keywords == $keywords" }
    ## get awards
    if [regexp {<h5>Awards:</h5>(.*?)</div>} $html dummy awards] {
       set awards [string map {"more" "" \n " "} $awards]
       regsub -all {<[^\>]*>} $awards {} awards
       set awards [string trim $awards]
       set awards [htmlparse::mapEscapes $awards]
    }
    if {$IMDB_DEBUG == 1} { putlog "IMDB_DEBUG awards == $awards" }
    ## get comment
    if [regexp {<h5>User Comments:</h5>\n(.*?)\n</div>} $html dummy comment] {
       set comment [string map {"more" "" \n " "} $comment]
       regsub -all {<[^\>]*>} $comment {} comment
       set comment [string trim $comment]
       set comment [htmlparse::mapEscapes $comment]
    }
    if {$IMDB_DEBUG == 1} { putlog "IMDB_DEBUG comment == $comment" }
    ## get iMDb rating
    if [regexp {<b>((\d.\d)/10)</b>.*?<a href="ratings".*?>([\d,]+).*?votes</a>} $html dummy rating goldstars votes] {

        #rating bar code
        set goldstars [expr round($goldstars)]
        set greystars [expr 10 - $goldstars]
        # generating the rating bar
        set marker "*"
        set rating_bar "$barcol1\[$barcol2"
        for {set i2 0} {$i2 < $goldstars} {incr i2 1} {
            set rating_bar "$rating_bar$marker"
        }
        set marker "-"
        set rating_bar "$rating_bar14"
        for {set i3 0} {$i3 < $greystars} {incr i3 1} {
            set rating_bar "$rating_bar$marker"
        }
        set rating_bar "$rating_bar$barcol1\]"
        #end rating bar code

    }
    if {$IMDB_DEBUG == 1} { putlog "IMDB_DEBUG rating == $rating | votes == $votes | rating bar == $rating_bar" }
    ## get TOP 250
    if [regexp {>(Top 250: #[\d]+)</a>} $html dummy top250] {
    } elseif [regexp {>(Bottom 100: #[\d]+)</a>} $html dummy top250] {
    }

    if {$IMDB_DEBUG == 1} { putlog "IMDB_DEBUG top250 == $top250" }
    ## get MPAA
    if [regexp {<h5><a href="/mpaa">MPAA</a>:</h5>(.*?)</div>} $html dummy mpaa] {
        regsub -all {<[^\>]*>} $mpaa {} mpaa
        #regsub {MPAA: } $mpaa {} mpaa
        set mpaa [string trim $mpaa]
        set mpaa [htmlparse::mapEscapes $mpaa]
    }
    if {$IMDB_DEBUG == 1} { putlog "IMDB_DEBUG mpaa == $mpaa" }
    ## get runtime
    if [regexp {<h5>Runtime:</h5>\n.*?([\d]+).*?\n} $html dummy runtime] {
        regsub -all {[\n\s]+} $runtime {} runtime
    }
    if {$IMDB_DEBUG == 1} { putlog "IMDB_DEBUG runtime == $runtime" }
    ## get country
    if [regexp {<h5>Country:</h5>\n(.*?)</div>} $html dummy country] {
        regsub -all {<[^\>]*>} $country {} country
        set country [string map {"|" "||" } $country]
        regsub -all {[\n]+} $country {} country
    }
    if {$IMDB_DEBUG == 1} { putlog "IMDB_DEBUG country == $country" }
    ## get language
    if [regexp {<h5>Language:</h5>\n(.*?)</div>} $html dummy language] {
        regsub -all {<[^\>]*>} $language {} language
        regsub -all {[\n]+} $language {} language
        set language [string map {"|" "||"} $language]
    }
    if {$IMDB_DEBUG == 1} { putlog "IMDB_DEBUG language == $language" }
    ## get movie color
    if [regexp {<h5>Color:</h5>(.*?)</div>} $html dummy movie_color] {
        regsub -all {<[^\>]*>} $movie_color {} movie_color
        regsub -all {[\n]+} $movie_color {} movie_color
        set movie_color [string trim $movie_color]
        set movie_color [string map {"|" "||"} $movie_color]
    }
    if {$IMDB_DEBUG == 1} { putlog "IMDB_DEBUG movie_color == $movie_color" }
    ## get aspect ratio
    if [regexp {<h5>Aspect Ratio:</h5>(.*?)</div>} $html dummy aspect_ratio] {
        regsub -all {<[^\>]*>} $aspect_ratio {} aspect_ratio
        set aspect_ratio [string map {"more" "" } $aspect_ratio]
        set aspect_ratio [string trim $aspect_ratio]
    }
    if {$IMDB_DEBUG == 1} { putlog "IMDB_DEBUG aspect_ratio == $aspect_ratio" }
    ## get soundmix
    if [regexp {<h5>Sound Mix:</h5>\n(.*?)</div>} $html dummy soundmix] {
        regsub -all {<[^\>]*>} $soundmix {} soundmix
        regsub -all {[\n]+} $soundmix {} soundmix
        set soundmix [string map {"|" "||"} $soundmix]
    }
    if {$IMDB_DEBUG == 1} { putlog "IMDB_DEBUG soundmix == $soundmix" }
    ## get certification
    if [regexp {<h5>Certification:</h5>\n(.*?)</div>} $html dummy cert] {
        regsub -all {<[^\>]*>} $cert {} cert
        regsub -all {[\n]+} $cert {} cert
        set cert [string map {"|" "||"} $cert]
    }
    if {$IMDB_DEBUG == 1} { putlog "IMDB_DEBUG cert == $cert" }
    ## get locations
    if { [regexp {<h5>Filming Locations:</h5>(.*?)</div>} $html dummy film_locations] } {
        set film_locations [string map {"more" "" } $film_locations]
        regsub -all {<[^\>]*>} $film_locations {} film_locations
        set film_locations [string trim $film_locations]
        set film_locations [htmlparse::mapEscapes $film_locations]
    }
    if {$IMDB_DEBUG == 1} { putlog "IMDB_DEBUG film_locations == $film_locations" }
    ## get company
    if [regexp {<h5>Company:</h5>(.*?)</div>} $html dummy company] {
        set company [string map {"more" "" } $company]
        regsub -all {<[^\>]*>} $company {} company
        set company [string trim $company]
    }
    if {$IMDB_DEBUG == 1} { putlog "IMDB_DEBUG company == $company" }
    
    ## get cast
    if [regexp {<table class="cast">(.*?)</table>} $html dummy cast] {
        regsub -all {</tr>.*?<tr.*?>} $cast \n cast_multiline
        regsub -all {<[^\>]*>} $cast_multiline {} cast_multiline
        set cast_multiline [string map {"rest of cast listed alphabetically:" \n} $cast_multiline]
        set cast_multiline [string trim [htmlparse::mapEscapes $cast_multiline]]
        if { $cast_linelimit > 0 } {
           set nthoccur [expr [findnth $cast_multiline \n $cast_linelimit] - 1]
           if {$nthoccur > 0} {set cast_multiline [string range $cast_multiline 0 $nthoccur]}
        }
    }
    if {$IMDB_DEBUG == 1} { putlog "IMDB_DEBUG cast_multiline == $cast_multiline" }
    ## fill singleline
    regsub -all {\n} $cast_multiline " / " cast_line
    if {$IMDB_DEBUG == 1} { putlog "IMDB_DEBUG cast_line == $cast_line" }


    # do we need the second page?

    if {[string match "*%budget*" $output] || [string match "*%screens*" $output]} {
        if {$IMDB_DEBUG == 1} { putlog "IMDB_DEBUG page2 needed" }
        unset html
        if { $IMDB_ALTERNATIVE == 0 } {
           set page2 [::http::config -useragent "MSIE 6.0"]
           if [catch {set page2 [::http::geturl ${newurl}business -timeout $imdb_timeout]} error ] {
              putserv "$toput :Error retrieving URL... try again later."
              ::http::Finish $page
              return
           }
           if {[::http::status $page2]=="timeout"} {
              putserv "$toput :\002Connection to imdb.com timed out.\002"
              ::http::Finish $page2
              return
           }
           set html [::http::data $page2]
           ::http::Finish $page2
        } else {
          catch { exec $binary(CURL) "${newurl}business" } html
        }
        ## get budget
        if [regexp {<h5>Budget</h5>\n(.*?)<br/>} $html dummy budget] {
           set budget [string map {&#8364; € &#163; £ } $budget]
        }
        if {$IMDB_DEBUG == 1} { putlog "IMDB_DEBUG budget == $budget" }
        ## get screens
        if [regexp {<h5>Opening Weekend</h5>\n(.*?Screens\))} $html dummy screens] {
           
           regsub -all {<[^\>]*>} $screens {} screens
           set screens [htmlparse::mapEscapes $screens]
        }
        if {$IMDB_DEBUG == 1} { putlog "IMDB_DEBUG screens == $screens" }
    }

    ## output results
    
    set output [replacevar $output "%title" $title]
    set output [replacevar $output "%url" $newurl]
    set output [replacevar $output "%name" $name]
    set output [replacevar $output "%genre" $genre]
    set output [replacevar $output "%tagline" $tagline]
    set output [replacevar $output "%plot" $plot]
    set output [replacevar $output "%keywords" $keywords]
    set output [replacevar $output "%awards" $awards]
    set output [replacevar $output "%comment" $comment]
    set output [replacevar $output "%rating" $rating]
    set output [replacevar $output "%rbar" $rating_bar]
    set output [replacevar $output "%votes" $votes]
    set output [replacevar $output "%top250" $top250]
    set output [replacevar $output "%mpaa" $mpaa]
    set output [replacevar $output "%time" $runtime]
    set output [replacevar $output "%country" $country]
    set output [replacevar $output "%language" $language]
    set output [replacevar $output "%mcolor" $movie_color]
    set output [replacevar $output "%aspect" $aspect_ratio]
    set output [replacevar $output "%soundmix" $soundmix]
    set output [replacevar $output "%cert" $cert]
    set output [replacevar $output "%locations" $film_locations]
    set output [replacevar $output "%company" $company]
    set output [replacevar $output "%budget" $budget]
    set output [replacevar $output "%screens" $screens]
    set output [replacevar $output "%reldate" $reldate]
    set checkvar ""
    regexp {.*?%castmline} $output checkvar
    if { [expr [regexp -all {%uline} $checkvar] % 2] == 1 } {
        set cast_multiline [string map {"\n" "\n%uline"} $cast_multiline]
    }
    if { [expr [regexp -all {%bold} $checkvar] % 2] == 1 } {
        set cast_multiline [string map {"\n" "\n%bold"} $cast_multiline]
    }
    if { [regexp {.*%color([\d]+(?:,[\d]+)?)[^\n]*?%castmline} $checkvar dummy colormline] } {
        regsub -all {\n} $cast_multiline "\n%color$colormline" cast_multiline
    }
    set output [replacevar $output "%castmline" $cast_multiline]
    set output [replacevar $output "%castline" $cast_line]
    set output [replacevar $output "%wcredits" $wcredits]
    regsub -all {\|[^\|]*?N/A[^\|]*?\|} $output "" output
    set output [string map {"||" "|" "|" ""} $output]
    regsub -all {\n[\n\s]*\n} $output "\n" output
    set output [string trim $output]
    set output [replacevar $output "%bold" "\002"]
    set output [replacevar $output "%color" "\003"]
    set output [replacevar $output "%uline" "\037"]
    foreach line [split $output "\n"] {
        putserv "$toput :$line"
    }
}

proc decr_inst { } {
     global IMDB_DEBUG instance
     if { $instance > 0 } { incr instance -1 }
     if { $IMDB_DEBUG == 1 } { putlog "IMDB_DEBUG instance decreased by timer to: $instance" }
}

proc wmsg { } {
     global warn_msg
     set warn_msg 0
}
putlog "IMDB info version 05.01.2010 loaded"
