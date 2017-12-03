# vim: expandtab
#
# This script makes the bot talk a bit. You can teach it terms to respond to. It
# also has random responses if it sees its nick mentioned.
#
# This is a heavily modified version of dictionary.tcl 2.7 by perpleXa.
#
# To enable the script on a channel type (partyline):
#  .chanset #channel +dictionary
#
# Dictionary
# Copyright (C) 2004-2007 perpleXa
# http://perplexa.ugug.org / #perpleXa on QuakeNet
#
# Redistribution, with or without modification, are permitted provided
# that redistributions retain the above copyright notice, this condition
# and the following disclaimer.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY, to the extent permitted by law; without
# even the implied warranty of MERCHANTABILITY or FITNESS FOR A
# PARTICULAR PURPOSE.

namespace eval dictionary {
  # Definition file. The format is a tcl dict.
  variable term_file "scripts/dbase/dictionary.db"

  # File containing nicks to not respond to. Newline separated.
  variable skip_nick_file "scripts/dictionary_skip_nicks.txt"

  # File containing affirmative responses. Newline separated.
  variable affirmative_responses_file "scripts/dictionary_affirmative_list.txt"

  # File containing negative responses. Newline separated.
  variable negative_responses_file "scripts/dictionary_negative_list.txt"

  # File containing chatty responses.
  #
  # These are really just random phrases
  # for the bot to respond with assuming it has been addressed in some way and
  # has nothing really to say about it. Newline separated.
  variable chatty_responses_file "scripts/dictionary_chatty_list.txt"

  # Time to not respond to the same word in the same channel. This is
  # so we don't respond to the same word in quick succession.
  variable throttle_time [expr 10*60]

  # Dictionary terms.
  #
  # Each key is a term and associates with another dict.
  #
  # The sub-dict has keys:
  # - def, the definition
  # - include_term_in_def, which controls whether we output "<term> is <def>"
  #   or just "<def>"
  variable terms [dict create]

  # Nicks to not respond to terms for. e.g., bots.
  variable skip_nicks [list]

  variable affirmative_responses [list]
  variable negative_responses [list]
  variable chatty_responses [list]

  # Dict with keys <channel><term> with values containing the unixtime the last
  # time the term was output, if any.
  #
  # This is for throttling term outputs.
  variable flood [dict create]

  bind pubm -|- "*" ::dictionary::public
  bind pubm -|- "*" ::dictionary::publearn

  setudef flag dictionary
}

# Respond to terms in the channel
proc ::dictionary::public {nick host hand chan argv} {
  variable flood
  variable terms
  variable throttle_time
  variable skip_nicks
  global botnick

  if {![channel get $chan dictionary]} {
    return
  }

  # Ignore cases of '<botnick>:' because those are commands to us. We deal with
  # them in a different proc.
  if {[::dictionary::is_addressing_bot $argv $botnick]} {
    return
  }

  # If the person saying something has a nick that is one we skip, we're done.
  foreach skip_nick $skip_nicks {
    if {[string equal -nocase $nick $skip_nick]} {
      return
    }
  }

  # Look for a word we know about for us to respond to.
  set term ""
  foreach word [dict keys $terms] {
    if {[::dictionary::string_contains_term $argv $word]} {
     set term $word
     break
    }
  }

  # If they didn't say a term we know something about, then the only response
  # we'll send is if they said our name. Send them a chatty response if so.
  if {$term == ""} {
    if {[::dictionary::string_contains_term $argv $botnick]} {
      set response [::dictionary::get_chatty_response $nick]
      putserv "PRIVMSG $chan :$response"
    }
    return
  }

  # They said a word we know something about. We'll potentially output the
  # definition.

  set term_dict [dict get $terms $term]

  # We throttle how often we output the term's definition.
  set flood_key $chan$term
  if {![dict exists $flood $flood_key]} {
    dict set flood $flood_key 0
  }
  set last_term_output_time [dict get $flood $flood_key]
  if {[unixtime] - $last_term_output_time <= $throttle_time} {
    return
  }
  dict set flood $flood_key [unixtime]

  # Output the definition. Note that terms get output differently depending on
  # how they were added.
  set def [dict get $term_dict def]

  if {[dict get $term_dict include_term_in_def]} {
    puthelp "PRIVMSG $chan :$term is $def"
    return
  }
  puthelp "PRIVMSG $chan :$def"
}

# Public trigger. This handles commands such as setting, deleting, and listing
# terms the bot knows about.
proc ::dictionary::publearn {nick host hand chan argv} {
  global botnick
  variable terms

  if {![channel get $chan dictionary]} {
    return
  }
  set argv [stripcodes "uacgbr" $argv]
  set argv [string trim $argv]

  # We only respond if we are directly addressed (botnick: ). This indicates
  # someone is giving us a command.
  if {![::dictionary::is_addressing_bot $argv $botnick]} {
    return
  }

  if {![regexp -nocase -- {^\S+\s+(.+)} $argv -> rest]} {
    set response [::dictionary::get_negative_response $nick]
    putserv "PRIVMSG $chan :$response"
    return
  }

  # Delete a term. <botnick>: forget <term>
  #
  # Note this means we can't set a term using the "is" syntax (e.g. forget blah
  # is x).
  if {[regexp -nocase -- {^forget\s+(.+)} $rest -> term]} {
    if {![dict exists $terms $term]} {
      set response [::dictionary::get_negative_response $nick]
      putserv "PRIVMSG $chan :I don't know `$term'."
      return
    }

    set def [dict get $terms $term def]
    dict unset terms $term
    ::dictionary::save

    putserv "PRIVMSG $chan :I forgot `$term'. (It was `$def'.)"
    return
  }

  # Set a term. <botnick>: <term> is <definition>
  if {[regexp -nocase -- {^(.+?)\s+is\s+(.+)$} $rest -> term def]} {
    if {[dict exists $terms $term]} {
      set def [dict get $terms $term def]
      putserv "PRIVMSG $chan :`$term' is already `$def'"
      return
    }

    dict set terms $term [dict create \
      def                 $def \
      include_term_in_def 1 \
    ]
    ::dictionary::save

    set response [::dictionary::get_affirmative_response $nick]
    putserv "PRIVMSG $chan :$response"
    return
  }

  # Set a term. <botnick>: <term>, <definition>
  if {[regexp -nocase -- {^(.+?)\s*,\s+(.+)$} $rest -> term def]} {
    if {[dict exists $terms $term]} {
      set def [dict get $terms $term def]
      putserv "PRIVMSG $chan :`$term' is already `$def'"
      return
    }

    dict set terms $term [dict create \
      def                 $def \
      include_term_in_def 0 \
    ]
    ::dictionary::save

    set response [::dictionary::get_affirmative_response $nick]
    putserv "PRIVMSG $chan :$response"
    return
  }

  # Message the nick all terms we have
  if {[string tolower $rest] == "listem"} {
    foreach term [lsort -dictionary [dict keys $terms]] {
      set def [dict get $terms $term def]
      puthelp "PRIVMSG $nick :$term: $def"
    }
    return
  }

  set response [::dictionary::get_chatty_response $nick]
  putserv "PRIVMSG $chan :$response"
}

# Return 1 if the given line is addressing the bot.
#
# This is the case if the line is of the form:
# <botnick>:
#
# For example if the bot's nick is:
# bot: Hi there
#
# This is checked case insensitively.
proc ::dictionary::is_addressing_bot {text botnick} {
  set text [string trim $text]
  set text [string tolower $text]

  set prefix [string tolower $botnick]
  append prefix :

  set idx [string first $prefix $text]

  return [expr $idx == 0]
}

# Return 1 if the string contains the term. This is tested case insensitively.
#
# The term is present only if it is by itself surrounded whitespace or
# punctuation.
#
# e.g. if the term is 'test' then these strings contain it:
#
# hi test hi
# hi test, hi
# test
#
# But these do not:
#
# hi testing hi
# hitest
proc ::dictionary::string_contains_term {s term} {
  set term_lc [string tolower $term]

  set term_quoted [::dictionary::quotemeta $term_lc]

  # \m matches at the beginning of a word, \M at the end.
  return [regexp -nocase -- \\m$term_quoted\\M $s]
}

# Escape/quote metacharacters so that the string becomes suitable for placing in
# a regular expression. This makes it so any regex metacharacter is quoted.
#
# See http://stackoverflow.com/questions/4346750/regular-expression-literal-text-span/4352893#4352893
proc ::dictionary::quotemeta {s} {
  return [regsub -all {\W} $s {\\&}]
}

proc ::dictionary::get_random_response {responses nick} {
  # We assume we have responses in the list.

  set response_index [rand [llength $responses]]
  set response [lindex $responses $response_index]

  return [regsub -all -- "%%nick%%" $response $nick]
}

proc ::dictionary::get_affirmative_response {nick} {
  if {[llength $::dictionary::affirmative_responses] == 0} {
    return "OK."
  }
  return [::dictionary::get_random_response \
    $::dictionary::affirmative_responses $nick]
}

proc ::dictionary::get_negative_response {nick} {
  if {[llength $::dictionary::negative_responses] == 0} {
    return "No."
  }
  return [::dictionary::get_random_response \
    $::dictionary::negative_responses $nick]
}

proc ::dictionary::get_chatty_response {nick} {
  if {[llength $::dictionary::chatty_responses] == 0} {
    return "Hi."
  }
  return [::dictionary::get_random_response \
    $::dictionary::chatty_responses $nick]
}

# Load the term database from our data file.
proc ::dictionary::load_terms {} {
  variable term_file
  variable terms
  set terms [dict create]

  if {[catch {open $term_file "r"} fp]} {
    return
  }
  set terms [read -nonewline $fp]
  close $fp
  set count [llength [dict keys $terms]]
  return $count
}

# Load contents of a file into a list.
#
# Each line of the file is made into one element in the list.
#
# Blank lines are skipped.
#
# Path: Path to the file to open
#
# Returns: If we do not find the file or we can't open it then we return an
# empty list.
proc ::dictionary::file_contents_to_list {path} {
  if {![file exists $path]} {
    return [list]
  }
  if {[catch {open $path r} fp]} {
    return [list]
  }
  set content [read -nonewline $fp]
  close $fp

  set l [list]
  foreach line [split $content "\n"] {
    set line [string trim $line]
    if {[string length $line] == 0} {
      continue
    }
    lappend l $line
  }
  return $l
}

# Load a list of nicks to skip from a data file.
proc ::dictionary::load_skip_nicks {} {
  set ::dictionary::skip_nicks [::dictionary::file_contents_to_list \
    $::dictionary::skip_nick_file]
}

# Load affirmative responses from data file.
proc ::dictionary::load_affirmative_responses {} {
  set ::dictionary::affirmative_responses [::dictionary::file_contents_to_list \
    $::dictionary::affirmative_responses_file]
}

# Load negative responses from data file.
proc ::dictionary::load_negative_responses {} {
  set ::dictionary::negative_responses [::dictionary::file_contents_to_list \
    $::dictionary::negative_responses_file]
}

# Load chatty responses from data file.
proc ::dictionary::load_chatty_responses {} {
  set ::dictionary::chatty_responses [::dictionary::file_contents_to_list \
    $::dictionary::chatty_responses_file]
}

# Load data from our data files into memory.
proc ::dictionary::load {args} {
  set term_count [::dictionary::load_terms]

  ::dictionary::load_skip_nicks

  ::dictionary::load_affirmative_responses
  ::dictionary::load_negative_responses
  ::dictionary::load_chatty_responses

  return $term_count
}

# Save the terms and definitions to the data file.
proc ::dictionary::write_db {} {
  variable term_file
  variable terms

  if {![file isdirectory [file dirname $term_file]]} {
    file mkdir [file dirname $term_file]
  }
  set fp [open $term_file w]
  puts -nonewline $fp $terms
  close $fp
}

set ::dictionary::count [::dictionary::load]
putlog "dictionary.tcl loaded. $::dictionary::count term(s)."
