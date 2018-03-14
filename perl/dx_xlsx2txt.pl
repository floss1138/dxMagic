#!/usr/bin/perl
# script to take .xlsx dx extracted file and create attout.txt formatted file

use strict;
use warnings;
use File::Copy;      # for move
use File::stat;      # for methods size, mtime etc.
use Carp;            # for croak
use
  Spreadsheet::Read; # required for xlsx read subroutine but this also requires:

# for XLSX, Spreadsheet::ParseXLSX needs to be installed - this one is required
# for XLS, Spreadsheet::ParseExcel needs to be installed
# for Libre office Spreadsheet::ReadSXC needs to be installed

use File::Basename;
use English qw(-no_match_vars);
 no warnings "uninitialized"
  ;    # prevents uninitialized warnings from ParseXLSX for blank cells in xlsx

our $VERSION = '0.0.06';

##  Custom variables go here ##

# path to dxMagic folders:
my $path ='/home/alice/MyCAD/dxMagic';
# Directories will be owned by the user running this script
# chown may be necessary

# dx insert folder [files for parsing]
my $dx_xlsxtotxt = "$path/dx_xlsx2txt_WATCH/";

# dx pass folder [processed xlsx files]
my $dx_pass = "$path/dx_pass/";

# dx fail folder [xlsx files that did not look like a dx, xlsx file]
my $dx_fail = "$path/dx_fail/";

# dx attin folder [processed xlsx converted to attin/attout files;
# these would typically be imported with the ATTIN command]
my $dx_attin = "$path/dx_attin/";

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

my $readme = $dx_xlsxtotxt . 'README.TXT';
if ( !open my $README, '>', $readme ) {
    print "\n  failed to open $readme\n";
}
else {

    my $read_me = << "NOTE";

      ## dxMagic xlsx to txt $VERSION watch folder ##\r\n  

dxMagic xlsx to txt takes dxMagic extracted xlsx then creates a tab deliminated attout.txt file, 
matching the format of ACADs ATTOUT tool.

Valid xlsx files found in this folder will be processed to create attout.txt metadata files.
These are written to $dx_attin, with the same file name but given a new .txt extension.
attout.txt files can be imported back into the originating drawing with the ATTIN command.
The source file is then moved to $dx_pass or $dx_fail folder as appropriate.

Files without xlsx extensions will be ignored.  This is a WATCH folder so the xlsx file need be complete when dropped.
Do not try saving the xlsx from within a spread sheet package,
to a WATCH folder as it will still be open in the editing application.

ATTIN is part of the Express Tools found in Full ACAD (or via the menu, Express > Blocks > Import Attribute Information).


      ## If you are irritated by every rub, how will you be polished? - Rumi ##
NOTE

    $read_me =~ s/\n/\r\n/gxsm;
    print $README "$read_me";
    close $README or carp "  could not close $read_me";
}
# set record sep back to undefined (only applies to print so cannot send heredoc to file handle)
undef $ORS;

## Sub to read xlsxtotxt watch folder ##

sub read_xlsxtotxt {
    my ($watch_folder) = @_;

    # print "  reading watchfolder $watch_folder\n"; exit 0;
    #  Define matching regex for dx files here
    my $match = '.*\.xlsx';

    opendir( DIR, $watch_folder )
      || croak "can't opendir $watch_folder - program will terminate";

    my @candidates =
      grep { !/^\./xms && -f "$watch_folder/$_" && (/$match/xsm) } readdir(DIR);

 # ignore readme.txt by removing if from the candidate array if found
 # my $index = 0;
 # $index++, until $candidates[$index] eq 'readme.txt';
 # splice is used a delete is deprecated.  1 is a single item at the index point
 # splice( @candidates, $index, 1 );

    # Concat path.filename with map
    my @candidates_withpath = map { $watch_folder . $_ } @candidates;

    # foreach (@candidates) {
    #  print "  Candidate file name:>$_< found with grep $watch_folder$match\n";
    #  }
    if ( !@candidates ) { print "  No candidate files found\n"; }

    return @candidates_withpath;
}    # End of read_xlstotxt


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

# enable for debug
# print "Second sheet (attout) cell B3 is:\n";
# print "$xlsx->[2]{B3} \n";
# Prints sheet 1, cell A1 usually HANDLE as a ceck but we start at A3. Will warn if cell blank: Use of uninitialized value in print at filename.pl

       # Print a row for testing:
       # my @row_test = Spreadsheet::Read::row( $xlsx->[1], 2 )
       #   ; # This returns [sheet], Row - all of it but if there are blanks it is an uninitialized value
       # print "Sheet 1, Row 2 contains @row_test\n";

        my $attin_ext = ".txt";    # File extension for attin files

        my $attin_file = $xlsxread;    # subsitute extension
        $attin_file =~ s/\.xlsx$/.txt/x;

        $attin_file =~ s/$dx_xlsxtotxt/$dx_attin/xsm
          ; # Substitute valid candidate directory with attin directory where file is to be written
        print "\n  attin file will be called $attin_file\n";
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
            my $rowlen = @row
              ; # number of elements in the array.  If its zero then the line is empty, but blank fields/tabs/whitespace count so need to check for uninitialized values

#        print "  Row is @row, count is $rowlen\n"; # To keep a left margin, row count is one more than the populated row
# Will bail out of the for loop if blank count exceeded i.e. if $blancount < 3 will stop after 3 totally blank lines
# xlscat could be used here to check the number of rows and columns.  Could also confirm sheet names. 
            if ( $rowlen == 0 ) {
                $blankcount++;    # print "blankcount is $blankcount\n";
            }
            if ( $rowlen > 1 ) {

                # print "row is $rowlen >> @row\n";
                my $firstelement = $row[1]
                  ; # check second element in array - if its HANDLE or '[any_uppercase_or_numbers x 2] then its a handle value, @row[0] better written $row[0]
                if ( $firstelement =~ /^HANDLE|^\'[A-Z0-9]{2}/x ) {

                    # enable for debug to print each row of xlsx:
                    # print "Row array contains: @row\n";

                    # Remove the margin i.e. the 1st element of array
                    my $margin = shift @row;

                    # Substitute special characters here
                    for (@row) 
                        {
                        s/&amp;/&/g;
                        s/&gt;/>/g;
                        s/&lt;/</g;
                        s/&quot;/"/g;
                        s/&apos;/'/g;
                        } 

  
                    print $FILEOUT "@row$/"
                      ; # The new line needs to be MS complient hence the $/ defined as \r\n
                        # clear content of row;
                    undef @row;
                }    # close if ($firstelement...
                else {
                    print
"!!! Row does not comply with attout format !!! & contains:\n@row\n";

                    # move failed file to failed folder:
                    my $xlsx_failed = $dx_fail . basename($xlsxread);
                    print "Moving $xlsxread to $xlsx_failed ... \n";
                    move( $xlsxread, $xlsx_failed )
                      or croak "move to $xlsx_failed failed";

                }
            }    # close if ($row > 1...
        }    # close for (my $rowcount...

        print "  attin file, $attin_file created\n";
        close($FILEOUT) or carp "Could not close $attin_file";

        # move xlsx file to passed folder

        my $passed = $dx_pass . basename($xlsxread);
        print "  moving $xlsxread to $passed\n";

        move( $xlsxread, $passed )
          or croak "move of $xlsxread to $passed failed";

    }    # if -e $xlsxread
return 0;
}    # close sub readxlsd

## STAT and SEEK sub, create unique string if file is static ##
# retrun 1 if cannot be read and 2 if not found #

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

### THE PROGRAM ###

#  Loop at 1 second interval (remember to $|++ if print is not flushed with \n)
while ( sleep 1 ) {

    # read watch folder for xlsx candidates
    my @xlsx_files = read_xlsxtotxt($dx_xlsxtotxt);
    if (@xlsx_files) {
        print "  Candidate xlsx file(s) found are @xlsx_files\n";
    }

    foreach (@xlsx_files) {

        my $dx = $_;
        print "  Checking $dx is static ...";
        my $stat1 = statnseek($dx);
        sleep 1;
        my $stat2 = statnseek($dx);

        # If file is static stat check will be the same string
        if ( $stat1 eq $stat2 ) {
            print "  OK\n";

            # If static, open file and check 1st line is acceptabale format
            if ( !open my $XFILE, '<', $dx ) {
                print "\n  failed to open $dx\n";
            }
            else {
                readxlsx($dx);
            }
        }    # end of if stat1 eq stat2
    }    # end of foreach @xlsx_files
    undef @xlsx_files;
    print "  End of processing, looking for more xlsx files ...\n";
}    # end of while (sleep)
exit 0;

__END__

# TODO

# Thanks to psynk, spreadsheet read needs some ASCII translation before $FILEOUT
sub FixXML {
    $parm = $_[0];
    $parm =~ s/&amp;/&/g;
    $parm =~ s/&gt;/>/g;
    $parm =~ s/&lt;/</g;
    $parm =~ s/&quot;/"/g;
    $parm =~ s/&apos;/'/g;
    $parm =~ s/&#xA;/\n/g;
    $parm =~ s/&#xa;/\n/g;
    $parm =~ s/&#xD;/\r/g;
    $parm =~ s/&#xd;/\r/g;
    $parm =~ s/&#x9;/\t/g;
    return($parm);
}

# Add -l functionality, same as extract and insert
