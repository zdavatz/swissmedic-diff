= swissmedic-diff

* http://scm.ywesee.com/?p=swissmedic-diff/.git;a=summary

== DESCRIPTION:

* Compares two Excel Documents provided by Swissmedic and displays the
salient differences. Also: Find out what Products have changed on the
swiss healthcare market.

Up-To-Date file:

* http://www.swissmedic.ch//daten/00080/00251/index.html


== FEATURES/PROBLEMS:

Swissmedic does not store old files. You must do this on your own.

Version 0.1.3 is capable of the Packungen.xls without column 'Gruppe',
column E in the previous format. If you want to use Packunge.xls 
including the column 'Gruppe', you should use version 0.1.2. After 
you get the source code via Git command, type in the swissmedic-diff 
directory as follows:

  * git checkout 4c8c9323297453c3cb3380a9d41457d534ed8861

Then you can get the version 0.1.2.

== REQUIREMENTS:

* ruby 1.8 (with oniguruma patch) or ruby 1.9
* spreadsheet

== INSTALL:

The easiest way to install is via RubyGems. On the command line enter:

* gem build swissmedic-diff.gemspec
* sudo gem install swissmedic-diff-0.1.3.gem

To manually install, use the included setup.rb script:

  * sudo ruby setup.rb

See test directory for tests. Run

  * ruby test/test_swissmedic-diff.rb

for testing.

== USAGE:

Usage: /usr/bin/swissmedic-diff [-gnr] <file1> <file2> [<output>]

  -g --group         sort by news, deletions and updates
  -n --name          sort by name
  -r --registration  sort by registration

== DEVELOPERS:

  * Hannes Wyss <hwyss@ywesee.com>
  * Masaomi Hatakeyama <mhatakeyama@ywesee.com>
  * Zeno R.R. Davatz <zdavatz@ywesee.com>

== LICENSE:

  * GPLv2
