This is a collection of scripts for the [Eggdrop](https://eggheads.org) IRC
bot. Most of them I've written, but some are edited versions of those
written by others.


# Scripts

* bash.tcl - Fetch and output bash.org quotes.
* calc.tcl - Provide `!calc` calculator function.
* dictionary.tcl - Make your bot respond to certain words/phrases.
  * This is a heavily modified version of dictionary.tcl 2.7 by perpleXa.
* horgh_autoop.tcl - Automatically op all users in a channel which is set
  `+horgh_autoop`.
* irb.tcl - Provide access to a Ruby interpreter in a channel. Very unsafe.
* latoc.tcl - Query Yahoo commodity listings for oil, gold, and silver
  futures.
* mysqlquote.tcl - Store and display quotes from a MySQL database.
  * I use
    [sqlquote.pl](https://github.com/horgh/irssi-scripts/blob/master/sqlquote.pl)
    these days.
* patternban.tcl - Ban people based on patterns. The patterns can be
  managed through binds.
* slang.tcl - Fetch and output definitions from urbandictionary.com.
* userrec.tcl - Provide access to the Eggdrop's user records by telling
  people in a channel who the bot thinks they are.
* weather-darksky.tcl - Look up weather from [Dark
  Sky](https://darksky.net).
* wiki.tcl - Fetch and output synopses from wikipedia.org.

Note some of these scripts may not work. Sometimes the APIs or webpages
they scrape go away or change and I might not use them any more and not
notice. If one doesn't work, please let me know, and I'll try to fix it (or
send me a pull request!). If it can't be fixed (or I don't want to for some
reason), it will be moved into the deprecated directory.

You might also be interested in [my Irssi
scripts](https://github.com/horgh/irssi-scripts/) and my [Irssi Tcl
scripts](https://github.com/horgh/irssi-tcl-scripts/).

# License
All scripts written by me in this repository are Public domain. Those not
written by me (even if edited) are under whatever license specified by
their authors.
