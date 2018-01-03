#!/usr/bin/perl

use strict;
use warnings;
use Carp;
use Spreadsheet::Read; # required for xlsx read subroutine but this also requires:
# for XLSX, Spreadsheet::ParseXLSX needs to be installed - this one is required
# for XLS, Spreadsheet::ParseExcel needs to be installed
# for Libre office Spreadsheet::ReadSXC needs to be installed

no warnings "uninitialized"; # prevents uninitialized warnings from ParseXLSX for blank cells in xlsx

our $VERSION = '0.0.01';

my $read_sheet = '/home/user1/dx_xlsx/25-20-3003-AD_from_prodge_all_bad_ending.xlsx';

# call readxlsx sub, xlsx to read is the 1st argument
readxlsx ($read_sheet);


## READ XLSX sub ##
# Take filename to read as argument

sub readxlsx # read xlsx and create an attin.txt file
{
my ($xlsxread) = @_; 
print "\nreadxlsx sub has been called, $xlsxread\n";

# If file is not found then the read will simply fail with an uninitialised error so check the file is present:
if (-e $xlsxread) 
    { print "$xlsxread will be processed:\n";
local $/ = "\r\n"; # new line defined for windows, might need to be local to read sub?
my $xlsx = ReadData ("$xlsxread");
print "Second sheet (attout) cell B3 is:\n";
print "$xlsx->[2]{B3} \n"; #Prints sheet 1, cell A1 usually HANDLE as a ceck but we start at A3. Will warn if cell blank: Use of uninitialized value in print at filename.pl
my @row = Spreadsheet::Read::row($xlsx->[1],2); # This returns [sheet], Row - all of it but if there are blanks it is an uninitialized value
print "Sheet 1, Row 2 contains @row\n";
my $attin_ext = ".txt"; # File extension for attin files

my $attin_file = $xlsxread; # subsitute extension 
$attin_file =~ s/\.xlsx$/.txt/x; 

# $attin_file =~ s/$vcdir/$attidir/; # Substitute valid candidate directory with attin directory where file is to be written
print "\nattin file will be called $attin_file\n";
open my $FILEOUT, ">", "$attin_file" or croak "Cannot open output file $!";  # with append access does not overwrite original.  foreach is OK if file remains open i.e. adds to existing content
local $" = "\t"; # set the output field separator to a tab
# Processing of spread sheet needs to stop at end of data but if there was a blank row or two then this is ignored 
# Only if 3 successive blank rows are found is the looping over.  This is achieved using a blank row counter
my $blankcount=0;
# Start processing sheet from 3rd line - this is the header.  1st 2 lines not used as top margin for notes
for (my $rowcount=3; $blankcount<3; $rowcount++)
        {
    
        my @row = Spreadsheet::Read::row($xlsx->[2],$rowcount); # read each row into an array
        my $row = @row; # number of elements in the array.  If its zero then the line is empty, but blank fields/tabs/whitespace count so need to check for uninitialized values
#        print "  Row is @row, count is $row\n"; # To keep a left margin, row count is one more than the populated row
        # Will bail out of the for loop if blank count exceeded i.e. if $blancount < 3 will stop after 3 (totally - no white space not tabs) blank lines        
        if ($row == 0)  {
                        $blankcount++; # print "blankcount is $blankcount\n";
                        }
        if ($row > 1)
                {
                # print "row is $row >> @row\n";
                my $firstelement = $row[1]; # check second element in array - if its HANDLE or '[any_uppercase_or_numbers x 2] then its a handle value, @row[0] better written $row[0]
                        if ($firstelement =~ /^HANDLE|^\'[A-Z0-9]{2}/)
                        {
                        print "Row array contains: @row\n"; # send this to a file and you have attout, this prints to screen for debug
                        # Remove the margin i.e. the 1st element of array 
                        my $margin = shift @row;    
                        print $FILEOUT "@row$/"; # The new line needs to be MS complient hence the $/ defined as \r\n 
                        } # close if ($firstelement...
                        else { print "!!! Row does not comply with attout format !!! : @row\n"; }
                } # close if ($row > 1...
        } # close for (my $rowcount...
   
print "attin file created\n";
close($FILEOUT) or carp "Could not close $attin_file";

    } # if -e $xlsxread
} # close sub readxlsd


