#!/usr/bin/perl
use strict;
use warnings;
use Carp;
use List::Util qw(first);

# used to find index of a specific array value

## dxMagic dx_inserts attin metadata into a dxf file ##
## reads attout.txt formatted file into hof_blocks then uses this to ##
## replace dxf attribute data, if the file names and metadata references match the corresponding attin.txt & dxf files ##

use POSIX qw( strftime );
use English qw(-no_match_vars);
use File::stat;
use File::Basename;
use File::Copy;
use File::Path 'rmtree';    # Exported by default
use Data::Dumper;

our $VERSION = '0.0.04';    # version of this script

##  Custom variables go here ##

# dx insert folder [files for parsing]
my $dx_insert = '/home/user1/dx_dxf_WATCH/';

# dx pass folder [processed files]
my $dx_pass = '/home/user1/dx_pass/';

# dx fail folder [files that did not look like a dx file]
my $dx_fail = '/home/user1/dx_fail/';

# dx attin folder [dx attout format metadata in either .txt or xlsx format to be replaced in corresponding dxf file]
my $dx_attin = '/home/user1/dx_attin_WATCH/';

# Program variables go here:

# hash of attributes to hold to hold lines from attout file is
my %hof_blocks;

my @folders = ( $dx_insert, $dx_pass, $dx_fail, $dx_attin );

# Print welcome message & check folders exist

print "\n ***  dxMagic insert $PROGRAM_NAME version $VERSION  ***\n";

# create folders if they do not exist & add readme
foreach (@folders) {
    print "  Checking $_ exists";

    #    mkdir($_) unless ( -d $_ );
    if ( !-d ) { print " - not found, so creating ...\n"; mkdir; }
    else       { print " - OK\n"; }
}

# Add readme.txt to dx_extract watch folder

my $readme = $dx_attin . 'readme.txt';
if ( !open my $README, '>', $readme ) {
    print "\n  failed to open $readme\n";
}
else {

    my $read_me = << "NOTE";

      ## dxMagic $VERSION attribute attin watch folder ##   

dxMagic insert takes attribute data from attribute.txt or attribute.xlsx formatted files,
then inserts this back into the originating .dxf file; similar to using ACADs ATTIN tool.

*** Ensure that a matching .dxf is already in $dx_insert before presenting the attribute file *** 

Valid .txt and .xlsx files found in this folder will be merged back into the originating .dxf file.
Attribute metadata is replaced in the matching .dxf file.
If no matching .dxf is found, the attribute file will be moved to the $dx_fail.

The original file is then moved to $dx_pass or $dx_fail folder as appropriate.
Files without txt and xlsx extensions will be ignored (including this readme.txt).

ATTIN is part of the Express Tools found in Full ACAD (or via the menu, Express > Blocks > Import Attribute Information).

      ## Stop acting so small.  What you seek is seeking you - Rumi ##
NOTE
    print $README "$read_me";
    close $README or carp " Cannot close $read_me";
}

## read_dx_attin sub to read dx files folder ##

# Sub to read attin watch folder passed as argument to read_dx_watch

sub read_dx_attin {
    my ($watch_folder) = @_;

    # print "  reading watchfolder $watch_folder\n";
    #  Define matching regex for dx files here
    my $match = '.*(\.txt|\.xlsx)';

    opendir( DIR, $watch_folder )
      || croak "can't opendir $watch_folder - program will terminate";

    my @candidates =
      grep { !/^\./xms && -f "$watch_folder/$_" && (/$match/xsm) } readdir(DIR);

    # ignore readme.txt by removing if from the candidate array if found
    my $index = 0;
    $index++, until $candidates[$index] eq 'readme.txt';

 # splice is used a delete is deprecated.  1 is a single item at the index point
    splice( @candidates, $index, 1 );

    # Concat path.filename with map
    my @candidates_withpath = map { $watch_folder . $_ } @candidates;

    # foreach (@candidates) {
    #  print "  Candidate file name:>$_< found with grep $watch_folder$match\n";
    #  }
    if ( !@candidates ) { print "  No candidate files found\n"; }

    return @candidates_withpath;
}

# End of read_dx_attin sub

## STAT AND SEEK SUBROUTINE ##

# Confirm if the file exists and can be read
# Return stat (byte count and mtime) with seek value if file exists and can be opened
# Check the last $bytes and append onto this the file size with mtime
# Return string looks like this: <cnseek_return>last_$last_bytes_of_file_end$bcount$mtime</cnseek_return>
# Return 1 if file cannot be opened for read
# Return 2 if file not found

# seek is used to set pointer to last $bytes from end of file, 2 is end, 1 is beginning 0 is current position

sub statnseek {
    my ($seekname) = @_;
    my $bytes = '20';  # constant - number of bytes to read/check at end of file

    my $seek_open_tag =
      '<cnseek_return>';    # xml style tag for count and seek string
    my $seek_close_tag = '</cnseek_return>';    # xml close tag
    my $file_end;    # variable to hold last $bytes of file
    if ( -f $seekname ) {

        if ( !open my $HANDLE, '<', $seekname ) {
            print "$seekname cannot be read\n";
            return 1;
        }
        else {

            seek $HANDLE, -$bytes, 2
              ; # number of bytes needs to be negative -$bytes as seek counts from the end if next argument is 2
            sysread $HANDLE, $file_end, $bytes;
            close $HANDLE or carp "Unable to close '$seekname'";

            # read $bytes of file from pointer position
            # my $bcount = -s $seekname; # now using stat size

            my $stats  = stat $seekname;
            my $bcount = $stats->size;
            my $mtime  = $stats->mtime;
            my $cnseek =
              $seek_open_tag . $file_end . $bcount . $mtime . $seek_close_tag;

# print "File end text $cnseek\n"; # enable for debug, print stat and seek value
            return $cnseek;

        }

    }

    else {
        print "$seekname not found\n ";
        return 2;
    }

}    # End of statnseek

## xparser sub ##

# xparser sub routine, take filename with path as argurment, return ref to hash of blocks (hashes)

# Takes approved candidate filename + path as argument  where a comma is a new line

# AcDbSequenceEnd & SEQEND codes may be optional and not used by prog

# ignoring 0 & 100 code and in this order of precedence
# HANDLE: (DOUBLE SPACE) 0, INSERT, (DOUBLE SPACE) 5, <HANDLE ENTITY H_xxxx>,
# BLOCKNAME: 100, AcDbBlockReference, (DOUBLE SPACE) 2, <BLOCKNAME> ,

# Beware AcDbAttribute comes before the 1, VALUE in a AUTO dxx and before the 2, TAG KEY in a PROG:
# AUTO DXX TAGS: 100, AcDbAttribute, (DOUBLE SPACE) 1,<TAG VALUE>,  (DOUBLE SPACE) 2, <TAG KEY>,
# PROG DXX & AUTO DXF TAGS: (DOUBLE SPACE) 1,<TAG VALUE>,  100, AcDbAttribute, (DOUBLE SPACE) 2, <TAG KEY>,
# So for both  using ATTRIB, (DOUBLE SPACE) 5, (DOUBLE SPACE) 1,<TAG VALUE>, (DOUBLE SPACE) 2, <TAG KEY>, instead of using AcDBAttribute
# ATTRIB, (DS)5, is followed by an incremented handel in dxx and an incremented handel then 330,<INSERT_HANDEL> in dxf, 330 is a pointer to the owner object

# using ATTRIB, (DS)5, instead of AcDbAttribute & allow for TAG before VALUE by having a $state VALUE OR $state TAG condition
# Capture Document $TITLE, (DS)1, <Drawing Tilte>
# Capture layout (viewport) tabs LAYOUT, (DS)5, AcDbLayout, (DS)1, <Layout Tag name>
# using $state to specifiy the actual match variable next required.

# Also looking for the dxf version (not present in a dxx)
# VERSION:  (DOUBLE SPACE) 9, $ACADVER, <VERSION CODE>,

# THINGS TO IGNORE:
# AcDb* (anything other than AcDbBlockReference), (DS) 2 may be problematic
# AcDbBlockBegin, (DS) 2,  DONT TAKE THIS VALUE
# BLOCK_RECORD, (DS), (DS) 5, This is followed by group codes for graphical block entities that can be ingnored, earler in file along with AcDbBlockTableRecord
# AcDbField is a default constructor in dxf with ..1 ..2 coded content that is not attribute releated,
# set state to FIELD to prevent further processing until next INSERT
# AcDbBlockBegin, (DOUBLE SPACE), 2, can be blockname or *Model_Space or *Paper_Space, then there is a (DS) 1 before the next INSERT, so dont start INSERT before -- wait for INSERT ... do this first
# AcDbBlockTableRecord, (DOUBLE SPACE) 2,
# AcDbDimStyleTableRecord, (DOUBLE SPACE) 2,
# AcDbSymbolTableRecord, (DOUBLE SPACE) 2,

# xinparser #
# Take target .dxf file, attin.txt filename and a pointer to headings/tags as input
# As the value comes before the property on approach is to cache
# the ATTRIB section and replace the value if necessary
# $attrib cache is undefined when not in use, chaned to empty once ATTRIB is encountered
# then populated until the next the property is found & replacement of the
# .dxf value from attin file can be made.
sub xinparser {
    my ( $dxf_file, $att_src, $tags ) = @_;
    my $state      = 'NOMATCH';    # current line state
                                   # deref tags
    my @properties = @$tags;
    my $attrib_cache;              # undefined
    my $handle    = 'No handle set';
    my $blockname = 'No blockname set';
    my $tagvalue  = 'No tagvalue set';
    my $tagkey    = 'No tagkey set';
    my $replaced  = 0;                    # number of replaced values in dxf
      #  new .dxf file + substitutions is created with a .tmp extension of the original
    my $temp_dxf = $dxf_file;
    $temp_dxf =~ s/\.dxf$/\.tmp/x;
    print
"  Lets update values in $dxf_file, for tags:\n@properties\n   and write to $temp_dxf\n";
    open( my $DXFFILE, '<', $dxf_file ) or croak "$dxf_file would not open";
    open( my $DXFTEMP, '>', $temp_dxf ) or croak "$temp_dxf would not open";

    # print $DXFTEMP "Test";
    while (<$DXFFILE>) {
        my $line = $_;

        # print "  State is $state\n";
        # Look for group 5 INSERT and then extract attribute metadata
        if ( $line =~ /^INSERT\r?\n/x ) { $state = 'INSERT'; }
        elsif ( $state eq 'INSERT' && $line =~ /^[ ]{2}5\r?\n/x ) {
            $state = 'INSERT5';

            # print "  State is now $state\n"; exit 1;
            # Find the handle and look it up
        }
        elsif ( $state eq 'INSERT5' ) {

            #  $line =~ s/\r?\n$//x;

            # if ( $handle ne $line ) { print "$handle ";}
            $handle = $line;
            $handle =~ s/\r?\n$//x;
            $state = "H_$handle" . '_';
        }
        elsif ( $state =~ /^H_.*_/x && $line =~ /^AcDbBlockReference/x ) {
            $state = $state . 'AcDbBlock';
        }
        elsif ( $state =~ /^H_.*AcDbBlock/x && $line =~ /^[ ]{2}2\r?\n/x ) {
            $state = $state . '2';
        }
        elsif ( $state =~ /^H_.*AcDbBlock2/x ) {

            # $line =~ s/\r?\n$//x;
            $blockname = $line;
            $blockname =~ s/\r?\n$//x;
            $state = 'BLOCKNAME';
        }
        elsif ( $state eq 'BLOCKNAME' && $line =~ /^ATTRIB/x ) {
            $state = 'ATTRIB';

# begin caching the file for subsequent replacement by making it empty (but not undefined)
            $attrib_cache = "";
        }

        elsif ( $state eq 'ATTRIB' && $line =~ /^[ ]{2}5\r?\n/x ) {
            $state = 'ATTRIB5';

            # append attrib cache?
            # $attrib_cache = $attrib_cache.$line;
        }
        elsif ( $state eq 'ATTRIB5' && $line =~ /^[ ]{2}1\r?\n/x ) {
            $state = 'VALUE';

        }
        elsif ( $state eq 'VALUE' ) {
            $state = 'TAGVALUE';

            # $line =~ s/\r?\n$//x;
            $tagvalue = $line;
            $tagvalue =~ s/\r?\n$//x;

# print " TAGVALUE: blockname for $handle is $blockname, state is $state, line is $line\n"
        }
        elsif ( $state eq 'TAGVALUE' && $line =~ /^[ ]{2}2\r?\n/x ) {
            $state = 'TAG';
        }
        elsif ( $state eq 'TAG' ) {

# Once a TAG is found the previous value may need replacing
# Keep looking for more attributes by setting state to BLOCKNAME to search for next value (value preceeds tag/key)
            $state = 'BLOCKNAME';

            # $line =~ s/\r?\n$//x;

            $tagkey = $line;
            $tagkey =~ s/\r?\n$//x;

# show handle with key and value taken from DXF for debug
# print "\nTarget Handle is $handle, Key from dxf is >$line<, Value is >$tagvalue< \n";
# array ref must not be undefined or script will bail, so testing for valid keys in $hof_blocks

            # add apostorphe to handle name to match that used in attout/attin
            my $handle = "'" . $handle;

            # print " handle is $handle\n";
            if ( exists $hof_blocks{$handle} ) {

                # print " $handle of dxf exists in the attin hash";

                my @attribs = @{ $hof_blocks{$handle} };

                # find positon of tag property in array based on

                # show attributes from hash for debug:
                # print "  Hash from attin contains @attribs\n";

# using List::Util like Javascript findIndex() for the position of the tag key $line within @properties, $# gives number of last element
# $tagkey is the current $line value chomped for \r \n
                my $index =
                  first { $properties[$_] eq $tagkey } 0 .. $#properties;
                my $tagvalue_in_hofb = $hof_blocks{$handle}[$index];

#  Enable for debug to see lines with tag/values
#                print
#"  Handle is $handle, Blockname from attin should be $hof_blocks{$handle}[1], $tagkey is at index $index, tagvalue in dxf is $tagvalue, tagvalue in attin hash is  $tagvalue_in_hofb\n";

# Enable quit for dbug if attin value contains for example BNC
# if ($tagvalue eq 'BNC') {print "   BNC value found so will exit now ...\n"; exit 1;}

  # if $tagvalue ne $tagvalue_in_dxf then replace the tagvalue and write to file
                if ( $tagvalue ne $tagvalue_in_hofb ) {
                    print
"  *** dxf needs $tagvalue updating with $tagvalue_in_hofb ***\n";

# tagvalue follows a double space 1 on the previous line to prevent a random match
# replace value in cache
                    $attrib_cache =~
                      s/^[ ]{2}1\r\n$tagvalue/  1\r\n$tagvalue_in_hofb/xsm;

                    # show attribute cahce for debug
                    # print "\n Attribute cache:\n$attrib_cache\n";

                    # output repalced cache content to file
                    print $DXFTEMP "$attrib_cache";

                    # increment replaced count
                    $replaced++;

                    # flush cache by making it undef, and continue
                    undef $attrib_cache;

                }
            }    # end of if handle exists in hash of blocks
            else { print "  $handle was missing from attin data\n"; }

            # print Dumper (\%hof_blocks);
            # foreach my $handles (keys %hof_blocks) { print "$handles ";}

# if $tagvalue from attin eq $tagvalue_in_dxf then there is no change, dump the cached content to file and clear the cache
# If there was replaced value then cache would have been cleared above, so defined check prevents and uninitialised error
            if ( defined $attrib_cache ) {
                print $DXFTEMP "$attrib_cache";
                undef $attrib_cache;
            }

        }    # end of if $state eq TAG

# if attrib cache not defined then its being populated following a ATTRIB line so keep filling it:
        if ( defined $attrib_cache ) { $attrib_cache .= $line; }

# if cache is filling, dont print out the next line but if it not part of an ATTRIB group then it OK to simply duplicate the original .dxf
        if ( !defined $attrib_cache ) { print $DXFTEMP "$line"; }

    # if ($line =~ m/C9859/xsm) { print "\n C9859 found - exiting\n"; exit 0; }
    # if $line matched it will have had the new line stripped so needs restoring
    # print "  Hash from attin contains @attribs\n";


    }    # End of while DXFILE
         #close dxf & .tmp files here
         # move attin file to passed directory
    my $passed = $dx_pass . basename($att_src);
    print "Moving attribute file $att_src to $dx_pass ... \n";
    move( $att_src, $passed ) or croak "move of $att_src failed";
    print "Data merge complete, moving $temp_dxf to $dxf_file \n";
    close $DXFFILE or croak " close of $dxf_file failed";
    close $DXFTEMP or croak " close of $temp_dxf failed";
    move( $temp_dxf, $dxf_file ) or croak "move of $temp_dxf failed";

    # replacement now complete, return replaced count
    return $replaced;
}

## dx_insert file checking sub
# take file name with path as argument and check $dx_insert folder for a valid file
# return 0 on success, 1 fails to open or not found, 2 invalid header
sub insert_target {
    my ($dxf_target) = @_;

    # print "  looking for $dxf_target ... ";
    # open dxf and check if its valid
    if ( !open my $TARGET, '<', $dxf_target ) {
        print "  Failed to open proposed merge target $dxf_target\n";
        return 1;
    }
    else {
        my $first = <$TARGET>;
        if ( $first =~ /^[ ]{2}0\r?\n/x ) {
            print
              "  merge target looks like an ASCII .dxf file, lets continue\n";
            close $TARGET or carp "could not close $dxf_target";
            return 0;

        }

        print "  target file header >$first< invalid, moving to $dx_fail\n";

        # Move invalid target to $dx_fail
        my $failed = $dx_fail . basename($dxf_target);
        move( $dxf_target, $failed ) or croak "move of $first failed";
        return '2';
    }    # else

}    # End of insert_target sub

### The Program ###

# hash of attays to hold to hold lines from attout file is %hof_blocks;

# loop forever with a 1 second pause between runs
while ( sleep 1 ) {

    # Read watch folder, looking for correctly named files
    my @attin_files = read_dx_attin($dx_attin);

    print "  Looking for candidate attin file(s) ... \n";
    if (@attin_files) { print "  Found @attin_files\n"; }

    # check candidate files are static and have expected header

    my $target;    # The internded dxf target tile name
    foreach (@attin_files) {

        # set state to valid as dx files exist

        my $attin = $_;

        # Cheeck to see if a matching dx file is present in $dx_insert
        $target = $dx_insert . basename($attin);

        # target is <name_of_attout>.dxf
        $target =~ s/\.txt$/\.dxf/x;
        my $insert_status = insert_target($target);
        print "  target is $target, status is $insert_status\n";
        print "  Checking $attin is static ...";
        my $stat1 = statnseek($attin);
        sleep 1;
        my $stat2 = statnseek($attin);

        # If file is static stat check will be the same string
        if ( $stat1 eq $stat2 ) {
            print "  OK\n";

            # If static, open file and check 1st line is acceptabale format
            open my $ATTOUT, '<', $attin or carp failed to open $attin;

            my $line = <$ATTOUT>;

            # Check first line starts with HANDLE
            if ( $line =~ m/^HANDLE/xsm ) {

                #   print " First line is valid \n$line\n";
                # split into chomped array
                my @attline = split( /\t/x, $line );    # split on tab

                foreach my $chomping (@attline) {
                    $chomping =~ s/\r?\n$//x;
                }

# array to preserve order (other than HANDLE this does not matter but it makes debugging easier)
                my @order = ( $attline[0] );
                print "  First item in header is $order[0]\n";

                # write header line to hash, where HANDLE, element 0, is the key
                $hof_blocks{ $order[0] } = \@attline;

                # print Dumper (\%hof_blocks);

                #  attout file name with path will be $atto
                #$atto = $dx_attout . basename($dx);
                #$atto =~ s/\.dx.$/\.txt/x;

           # print "  Looking for existing attout file, \n  $atto\n";
           #if ( -e "$atto" ) {
           #   print
           #"  Old $atto already exists, \n  ... so its going to be deleted!\n";

        #                       unlink $atto or carp "  Could not delete $atto";
        #    }

                while (<$ATTOUT>) {

                    # If valid start to line
                    if ( $_ =~ /^'[0-9A-F]/xsm ) {

                        #     print ("$_");

                        my @att = split( /\t/x, $_ );    # split on tab
                           # It seems necessary to leave the newline in before the split as an empty attribute value
                           # will be missed if this is the last item in the intended array.  Chomp each value in the array
                           # after the split
                        foreach my $chomping (@att) {
                            $chomping =~ s/\r?\n$//x;

                            # add handle reference to order array
                            push @order, $att[0];

                        }

   # write array @att to hash, [0] is the key and the first element of the array
                        $hof_blocks{ $att[0] } = \@att;

                    }    # if valid start
                }    # while file open ...
            }    # first line OK

        }    # if static
             # print " attin is $attin\n";

        #    }    # end of foreach dx_file
        #  print Dumper (\%hof_blocks);

        # enable for debug
        #   foreach my $handles (keys %hof_blocks) {
        #   list  handle then the array (1st element is also handle) for debug
        #   print "  -v-v-v- $handles -v-v-v-\n";
        #       foreach my $attribs (@{$hof_blocks{$handles}}){
        #       print "$attribs\n";
        #       }
        #  }
        # extract heading line from hash if it has been populated
        my $replaced_count = 0;   # Replaced value count returned from xinparser
        if (%hof_blocks) {
            my @heading = @{ $hof_blocks{'HANDLE'} };
            print "  Heading is @heading\n";

# call xinparser, $target is dx merge target, $attin is metadata source file .txt, heading is pointer to heading array
            $replaced_count = xinparser( $target, $attin, \@heading );
        }

        # clear hash of blocks before next run
        undef %hof_blocks;
        print
" \nEnd of processing, $replaced_count replacments , lets check the watchfolders again...\n";
    }    # new end of foreach dx_file
         # set dx_state to invalid until more files found

}    # end of while (sleep 1)

exit 0;

__END__


