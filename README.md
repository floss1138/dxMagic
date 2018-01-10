# dxMagic
Proof of concept DXF and DXX file parser to extract attribute meta-data

dxMagic is a proof of concept attempt to take dxx output from AutoKAD LT/ProgKAD and turn it into an ATTOUT formatted text file.  This provides similar results to the ATTOUT function available in the full version of AutoKAD but using the `ATTEXT` function instead of `ATTOUT`.  With little modification it is possible to extend dxx parsing to ASCII dxf files.  This makes it possible to extract attribute data directly from the drawing file without the need to open it in a CAD package.   

### Looking for a CAD tutorial?
Please excuse the alternative spellings; they are intended to prevent search engines picking up this document. Some AutoKAD commands will be explained but this is not a CAD tutorial. There are lots of good tutorials for AutoKAD. This is not one of them.

## USING dx_extract
dxMagic is watch folder based.  dx_extract.pl will create the necessary folder structure when run (if not already present).  Edit the header of the script as necessary to create the desired folders.  The defaults begin with *dx_* to show they belong to dxMagic and end in *_watch* if this is a trigger folder. Defaults are:
dx_extract_WATCH folder is for the dxx or dxf files to be parsed.
dx_pass is where successfully processed files are moved to.
dx_fail is for files which failed (valid file name but invalid content).
dx_attout is the resulting attout.txt files, keeping the same name but with a new extension.
dx_xlsx is the resulting attout.txt file converted to .xlsx format.

The dx_extract_watch folder contains a readme with more information.  Files without the extension .dxx and .dxf (lower case) will not be processed.

## USING dx_insert
dx_insert takes an attout.txt formatted file (from AutoKADs attout/export attributes or dx_extract) and merges this data back into a dxf file of the same name (and the same meta-data of course)
The default folders begin with *dx_* to show they belong to dx_magic   
dx_attin_WATCH is for the attribute.txt file.  Must have the same name as the dxf other than the extension.   
dx_dxf4insert is for the .dxf file intended for attribute replacement.     
During attribute replacement a temporary file will be created in dx_dxf_WATCH with a .tmp extension.  The updated file will replace the original .dxf.
The attribute .txt file will be moved to the pass folder on successful completion; however, the .dxf will remain in dx_dxf_WATCH pending further updates.   

## USING dx_xls2txt
dx_xlsx2txt takes xlsx files created with dx_extract and converts these to attout.txt format.  This in turn can be inserted with dx_insert or imported with AutoKADs ATTIN command.   
dx_xlsx2txt_WATCH is for the .xlsx files produced by dx_extract. File must have an .xlsx extension.  
dx_attin is the destination for the converted file.  attin/attout files should always have .txt extensions and Windows format new lines.   
The .xlsx file produced by dx_extract has the first 2 rows and the first column as margin space.  These must remain & can be used for comments. 
In the future, the left most column might be used to flag a row for further processing if it contains the relevant command.   

### Installing dxMagic
dxMagic is just a Perl script.  Excel creation requires Excel::Writer::XLSX module to be installed.  Spreadsheet::Read is required for xlsx read subroutine but this also requires XLSX, Spreadsheet::ParseXLSX, once installed you have 'xlscat' at command line which is handy for teseting.  For Windows, install Strawberry Perl, use cpan to install cpanm,`cpan App::cpanminus`,  then install the modules with the cpan command, for example `cpanm Excel::Writer::XLSX`.  Edit the script header to create the necessary folders (with appropriate slash separators for your OS).

## A note on file formats ##
.dwg AutoKAD proprietary drawing format    
.dxf Drawing interchange format in ASCII or binary (always ASCII before 2010) see `DXFOUT`, `DXFIN`    
.dxb Drawing interchange binary used for flattening 3D wireframe to 2D vectors    
.dxx Drawing interchange format but a selected fragment of the drawing in dxf format    
.dwf Design Web Format, an open format based on ISO/IEC 29500-2:2008, see also DWFx  

In ProgKAD the ASCII or binary dxf is an obvious *save as* file selection.  In AutoKAD, binary dxf is selected in the *save as* Tools drop down >  Options > DXF Options tab,  Default is ASCII.   
Although binary files are smaller and preserve floating point accuracy from the original drawing, only ASCII dxf is supported by dxmagic.
	
## AutoKAD meta-data - a concise explanation for programmers

AutoKAD can group graphical lines and key(property)/value data by creating a block.  This allows for easy duplication of commonly used items; for example, a block can be created for a chair and re-used several times in an office layout.  The chair block can optionally contain multiple key(property)/value pairs of meta-data, called attributes, designed to describe the chair or furniture class object.
The data key is called a TAG and the value can display as text on a drawing layer or be hidden. The TAG name cannot contain spaces and is normalised to upper case. Think of creating a block with attribute meta-data as creating a data object.   

Attribute values can be automatically populated with CAD variables such as the drawing title, date, file name, user, etc.  The default value is populated when the block is inserted.  When attributes are manually populated, a prompt can be issued to remind the user what is required for an attribute value on an attribute by attribute basis.  The value can also be a predetermined constant.   

Drawing text is graphical and part of the drawing.  Attribute text is abstracted from the drawing and can be replaced without changing the graphical part of the design.  Attribute text can be turned into drawing text with the `BURST` command.  BURST text will remain as a static part of the drawing.   

Blocks are referenced by AutoKAD automatically adding an entity HANDLE that will be unique for that drawing.  
DXF format associates the HANDLE reference with group code 5. The HANDLE is a text string of up to 16 hexadecimal digits.  The HANDLE is a hard reference and will not be changed by purge operations.  
Copying a block, even from another drawing will result in the HANDLE entity being replaced.  Every block/object has a reserved field for the BLOCKNAME.   

Blocks can be used to created classes of objects to describe the designers environment.  A sensible implementation would use the BLOCKNAME to indicate the class it belongs to.  Adding a version number to the BLOCKNAME is considered best practice.
The HANDLE is unique only to the drawing and has no scope beyond the drawing in which it resides.  In practice this means the HANDLE and BLOCKNAME can be duplicated in completely different drawings.  With careful naming conventions it is possible to use this mechanism to reference an object with a combination of HANDLE and document identifier so that it is unique for any document within an enterprise.   

Full AutoKAD (2004 and higher) has express tools to perform attribute export/import (Express > Blocks > Export/Import Attribute Information, commands are `ATTOUT`/`ATTIN`).  Express tools installed by default from 2008 on wards.  `ATTOUT` produces a tab deliminated text file with the first row always containing the headings (TAGs).  The first two columns are always HANDLE and BLOCKNAME.  The handle entity has a leading single quote added.  Empty values are blank.  Missing values (think of cells in a row) will be present if the block has no corresponding TAG (column).  Missing values in a column are packed with <>.  ATTOUT only works with level one blocks (i.e. not nested).   

AutoKAD light and ProgKAD do not have the attribute import/export tool; however, the earlier `ATTEXT` command also present in full AutoKAD is available.  `ATTEXT` can be used to produce a comma or space delimited file but for these formats it is necessary to provide a template file.  Obviously the template would have to be updated every time a new block with different tags is created i.e. new tags or object classes require template changes.  The BL:HANDLE will be required as a reference to import the data back into the drawing.  The DXX option provides a  file output which is a fragment of the DWG format.  DXX is more flexible with no need for a template but parsing of the resulting file will be required.  There are differences in the resulting data between ProgKAD and AutoKAD but the objective is to provide transparent parsing of dxx/dxf. The Design Web Format is out of scope.  DWG TrueView (a free utility) will save to different versions of DWG and will export DWF & DWFx but will not save to DXF.  TrueView will open DXF for viewing and save to DWG.

Auto & Prog will save DWG to DXF but it is best practice to use the `AUDIT` command to clean up the drawing prior to saving to DXF.  `PURGE` & `OVERKILL` are also useful for removing unwanted drawing components.  AutoKAD has been known to save into DXF and then not be able to load the file it just saved, without AUDITing first. The `ATTEXT` command (same as the earlier `DDATTEXT` command) can be used to save a selected area on a drawing in either MODEL or PAPER space.

Auto/ProgKAD has two different view modes.  MODEL space is where the design work is actually done and has defined units of measure to a defined resolution.  A viewport is created into the MODEL space, usually scaled to fit a given paper size.  Typically a drawing boarder is placed within the PAPER space so the viewport shows the desired area of the model scaled within the boarder.  The boarder can contain blocks and will usually contain attribute data to show the document title, versions & revisions.  The `ATTEXT` function can only select and create a dxx export from the drawing space visible at the time.  The dxf file is for a whole drawing, so parsing this file will result in all the meta-data from both MODEL and PAPER space being extracted. 

To display the block handle value from the drawing use the command `BLOCK?` (assuming you have Express Tools available) or using Lisp `(entget (car (entsel)))`

