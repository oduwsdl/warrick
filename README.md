# Warrick
The website reconstructor

Version 2.0

## Dependencies 
* Perl5 or later
* cURL
* Python
* Perl libraries: HTML::TagParser, LinkExtractor, Cookies, Status, and Date, and the URI library

## Installation
Install Warrick's dependencies on the command line by running:

```sh
./INSTALL
```

Test the installation by running:

```sh
./TEST
```

This will recover a web page and compare it to a master copy.

For further options and information on using warrick, run:

```sh
perl warrick.pl --help
```

This version of Warrick has been redesigned to reconstruct lost
websites from the Web Infrastructure using [Memento](http://www.mementoweb.org/).

## Recovery Process Details

This program creates several files that provide information or log data about the recovery. 

For a given recovery RECO_NAME, we will create a RECO_NAME_recoveryLog.out, PID_SERVERNAME.save,
and logfile.o. These are created for every recovery job. RECO_NAME_recoveryLog.out is created in the home warrick directory, and contains a report of every URI recovered, the location of the recovered archived copy (the memento), and  the location the file was saved to on the local machine in the following format:
* ORIGINAL URI => MEMENTO URI => LOCAL FILE
* 
Lines pre-pended with "FAILED" indicate a failed recovery of ORIGINAL URI

PID_SERVERNAME.save is the saved status file. This file is stored in the recovery directory and contains the information for resuming a suspended recovery job, as well as the stats for the recovery, such as the number of resources failed to be recovered, the number from different archives, etc. logfile.o is a temporary file that can be regarded as junk. It contains the headers for the last recovered resource.

## History 

* Modified by Justin F. Brunelle ([@jbrunelle](https://github.com/jfbrunelle)) at Old Dominion University - 2011
* Created by Frank McCown ([@fmccown](https://github.com/fmccown)) at Old Dominion University - 2006

## Contact 

We want to know if you have if you have used Warrick toreconstruct your lost website. If you have successfully recovered your site or  would like to assist in further development and improvements Warrick, please [Open a GitHub issue](https://github.com/oduwsdl/warrick/issues/new) and/or contact jbrunelle@cs.odu.edu.

## License

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

The GNU General Public License can be seen here:
http://www.gnu.org/copyleft/gpl.html

-----------------------------------------------------------

