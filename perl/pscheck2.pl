#!/usr/bin/perl
use strict;
use warnings;
use English qw( -no_match_vars );
use IPC::Open2;
use Carp;    #qw(:DEFAULT cluck);

my $script = $PROGRAM_NAME;

# This is a script running check, using ps to list processes and grep to filter the output
# The regex trick to remove grep from the process output uses, [^]]
# A bracket expression is either a matching list expression or a non-matching list expression.
# A non-matching list expression begins with a circumflex.
# so [^]] excludes a square bracket & actually adds the square bracket to the grep pattern then it will never match itself.
my $gfix = '[^]]';

# Check for options, if none found, set to 'None'
my $option = shift @ARGV || 'None';

# if @ARGV undef then || 'None' makes it never undef
# prevents 'Use of uninitialized value'

if ( $option =~ /-h/xsm ) {
    print "   -l option can be used to loop forever\n    Also, shows output on each loop\n";
    exit 0;
}
print "  script is $script, options are: $option\n";

## sub to check if a process is running. Takes process name,
# returns number of matching processes running

sub check_script_run {
# requires IPC:Open2
    my @sname = @_;

    # process count of number of matching scripts running
    my $ps_count = 0;

    # add script name after [^]]
    my $grepscript = $gfix . $sname[0];

    # print "  grep script is now $grepscript\n";

# requires ps command or will throw a sh: 1: ps: not found error (not intended for Windows
# try, if ( $OSNAME eq 'MSWin32' ) { my $pid = open2( \*OUT, 0, 'tasklist /v' ) }
# \* is a reference to a file handle, * referes to all variables regardless of type
    eval {
        my $pid = open2( \*OUT, 0, "ps -ef | grep $grepscript" );
        1;
    }
      or confess
"Call to run ps -ef | grep $grepscript and existing proces check failed\n";

    while (<OUT>) {
        print "  grep: $_\n";
        if ( $_ =~ /$script/ixms ) {
            $ps_count++;

            # print "  matched $script, count is $ps_count\n";
        }
    }
    return $ps_count;
}    # end of check_script_run sub

# check if this script is already running
my $psc = check_script_run($script);
if ( $psc > 1 ) {
    confess
"  $script was found $psc time(s), a previous instance is running; time to die!!!\n";
}

my $loop = 1;

while ($loop) {
    print "  loop is running\n";
    if ( $option =~ m/-l/xsm) { print "  -l option was used so this message will appear!\n";}

    # if loop -l switch not applied, dont loop, by making loop zero
    if ( $option !~ m/-l/xsm ) { $loop = 0; }
    sleep 1;
}

# if loop active this script wont exit
exit 0;
