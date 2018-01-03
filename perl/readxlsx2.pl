#!/usr/bin/perl
# script to take .xlsx dx extracted file and create attout.txt formatted file

use strict;
use warnings;
use Carp;
use
  Spreadsheet::Read; # required for xlsx read subroutine but this also requires:

# for XLSX, Spreadsheet::ParseXLSX needs to be installed - this one is required
# for XLS, Spreadsheet::ParseExcel needs to be installed
# for Libre office Spreadsheet::ReadSXC needs to be installed

use File::Basename;
use English qw(-no_match_vars);
no warnings "uninitialized"
  ;    # prevents uninitialized warnings from ParseXLSX for blank cells in xlsx

our $VERSION = '0.0.02';

##  Custom variables go here ##

# dx insert folder [files for parsing]
my $dx_xlsxtotxt = '/home/user1/dx_xlsxtotxt_WATCH/';

# dx pass folder [processed xlsx files]
my $dx_pass = '/home/user1/dx_pass/';

# dx fail folder [xlsx files that did not look like a dx, xlsx file]
my $dx_fail = '/home/user1/dx_fail/';

# dx attin folder [processed xlsx converted to attin/attout files; 
# these would typically be imported with the ATTIN command]
my $dx_attin = '/home/user1/dx_attin/';

my @folders = ( $dx_pass, $dx_fail, $dx_attin, $dx_xlsxtotxt );

print "\n ***  dxMagic xlsx to txt $PROGRAM_NAME version $VERSION  ***\n";

# create folders if they do not exist & add readme
foreach (@folders) {
    print "  Checking $_ exists";

    #    mkdir($_) unless ( -d $_ );
    if ( !-d ) { print " - not found, so creating ...\n"; mkdir; }
    else       { print " - OK\n"; }
}
    # Add readme.txt to dx_xlsxtotxt watch folder
    my $readme = $dx_xlsxtotxt . 'readme.txt';
    if ( !open my $README, '>', $readme ) { 
        print "\n  failed to open $readme\n";
    }   
    else {

        my $read_me = << "NOTE";

      ## dxMagic xlsx to txt $VERSION watch folder ##   

dxMagic xlsx to txt takes dxMagic extracted xlsx then creates a tab deliminated attout.txt file, 
matching the format of ACADs ATTOUT tool.

Valid xlsx files found in this folder will be processed to create attout.txt metadata files.
These are written to $dx_attin, with the same file name but given a new .txt extension.
attout.txt files can be imported back into the originating drawing with the ATTIN command.
The source file is then moved to $dx_pass or $dx_fail folder as appropriate.

Files without xlsx extensions will be ignored.

ATTIN is part of the Express Tools found in Full ACAD (or via the menu, Express > Blocks > Import Attribute Information).

      ## If you are irritated by every rub, how will you be polished? - Rumi ##
NOTE
        print $README "$read_me";
        close $README or carp "  could not close $read_me";
    }

## Sub to read xlsxtotxt watch folder ##

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

# TODO read xlsx watch folder an process candidates instead of just read_sheet

my $read_sheet =
  '/home/user1/dx_xlsx/25-20-3003-AD_from_prodge_all_bad_ending.xlsx';

# call readxlsx sub, xlsx to read is the 1st argument
readxlsx($read_sheet);

## READ XLSX sub ##
# Take filename to read as argument

sub readxlsx    # read xlsx and create an attin.txt file
{
    my ($xlsxread) = @_;
    print "\nreadxlsx sub has been called, $xlsxread\n";

# If file is not found then the read will simply fail with an uninitialised error so check the file is present:
    if ( -e $xlsxread ) {
        print "$xlsxread will be processed:\n";
        local $/ = "\r\n"
          ;  # new line defined for windows, might need to be local to read sub?
        my $xlsx = ReadData("$xlsxread");
        print "Second sheet (attout) cell B3 is:\n";
        print "$xlsx->[2]{B3} \n"
          ; #Prints sheet 1, cell A1 usually HANDLE as a ceck but we start at A3. Will warn if cell blank: Use of uninitialized value in print at filename.pl
        my @row = Spreadsheet::Read::row( $xlsx->[1], 2 )
          ; # This returns [sheet], Row - all of it but if there are blanks it is an uninitialized value
        print "Sheet 1, Row 2 contains @row\n";
        my $attin_ext = ".txt";    # File extension for attin files

        my $attin_file = $xlsxread;    # subsitute extension
        $attin_file =~ s/\.xlsx$/.txt/x;

# $attin_file =~ s/$vcdir/$attidir/; # Substitute valid candidate directory with attin directory where file is to be written
        print "\nattin file will be called $attin_file\n";
        open my $FILEOUT, ">", "$attin_file"
          or croak "Cannot open output file $!"
          ; # with append access does not overwrite original.  foreach is OK if file remains open i.e. adds to existing content
        local $" = "\t";    # set the output field separator to a tab

# Processing of spread sheet needs to stop at end of data but if there was a blank row or two then this is ignored
# Only if 3 successive blank rows are found is the looping over.  This is achieved using a blank row counter
        my $blankcount = 0;

# Start processing sheet from 3rd line - this is the header.  1st 2 lines not used as top margin for notes
        for ( my $rowcount = 3 ; $blankcount < 3 ; $rowcount++ ) {

            my @row = Spreadsheet::Read::row( $xlsx->[2], $rowcount )
              ;    # read each row into an array
            my $row = @row
              ; # number of elements in the array.  If its zero then the line is empty, but blank fields/tabs/whitespace count so need to check for uninitialized values

#        print "  Row is @row, count is $row\n"; # To keep a left margin, row count is one more than the populated row
# Will bail out of the for loop if blank count exceeded i.e. if $blancount < 3 will stop after 3 (totally - no white space not tabs) blank lines
            if ( $row == 0 ) {
                $blankcount++;    # print "blankcount is $blankcount\n";
            }
            if ( $row > 1 ) {

                # print "row is $row >> @row\n";
                my $firstelement = $row[1]
                  ; # check second element in array - if its HANDLE or '[any_uppercase_or_numbers x 2] then its a handle value, @row[0] better written $row[0]
                if ( $firstelement =~ /^HANDLE|^\'[A-Z0-9]{2}/ ) {
                    print "Row array contains: @row\n"
                      ; # send this to a file and you have attout, this prints to screen for debug
                        # Remove the margin i.e. the 1st element of array
                    my $margin = shift @row;
                    print $FILEOUT "@row$/"
                      ; # The new line needs to be MS complient hence the $/ defined as \r\n
                }    # close if ($firstelement...
                else {
                    print
                      "!!! Row does not comply with attout format !!! : @row\n";
                }
            }    # close if ($row > 1...
        }    # close for (my $rowcount...

        print "attin file created\n";
        close($FILEOUT) or carp "Could not close $attin_file";

    }    # if -e $xlsxread
}    # close sub readxlsd

