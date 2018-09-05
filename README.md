# dxMagic
Proof of concept DXF and DXX file parser to extract attribute meta-data.  This collection of Perl scripts is intended to run on Ubuntu server for which there is a build script.

dxMagic is a proof of concept attempt to take dxx output from AutoKAD LT/ProgKAD and turn it into an ATTOUT formatted text file.  This provides similar results to the ATTOUT function available in the full version of AutoKAD but using the `ATTEXT` function instead of `ATTOUT`.  With little modification it is possible to extend dxx parsing to entire ASCII dxf files.  In the case of a dxf file, all the attribute data from both model and paper space is extracted.  dx_extract makes it possible to extract attribute data directly from the drawing file without the need to open it in a CAD package.  `ATTIN` functionality is similarly provided by merging attribute data back into the .dxf using dx_insert.

### Looking for a CAD tutorial?
Please excuse the alternative spellings; they are intended to prevent search engines picking up this document. Some AutoKAD commands will be explained but this is not a CAD tutorial. There are lots of good tutorials for AutoKAD. This is not one of them.

## USING dxMagic
dxMagic is watch folder based.  Folder names can be changed in the header of the scripts. Default names begin with *dx_* to show they belong to dxMagic and end in *_WATCH* if this is a trigger folder.  Placing a file in the WATCH folder will initiate file processing.  A dxf formatted file (name matched to the attribute file) also needs to be present as the dx_insert target.  In addition to the attout formatted text file an xlsx spread sheet is also provided.  This can be edited and converted to and attin/attout formatted text file with dx_xls2txt.  The build script will create an example directory structure, making this available as SAMBA shares.  Run the extract/insert/xlsx2txt scripts with -l for looping with verbose output. Use the dx_loop script to run all the scripts together and send the output to syslog.

dx scripts will create the necessary folder structure when run (if not already present)   
**dx_extract_WATCH** folder is for the dxx or dxf files to be parsed & has a readme for more info.   
**dx_pass** is where successfully processed files are moved to.   
**dx_fail** is for files which failed (valid file name but invalid content).   
**dx_attout** is the resulting attout.txt files, keeping the same name but with a new extension.   
**dx_xlsx** is the resulting attout.txt file converted to .xlsx format.   
**dx_xlsx2txt_WATCH** is for converting .xlsx files to attribtue.txt
**dx_attin** holds attribute.txt files converted from .xlsx.    
**dx_dxf4insert** should contain .dxf target files to accept data introduced to the **dx_insert_WATCH**

## USING dx_extract (-h -l)
`dx_extract.pl` Extracts attribute data from .dxx and .dxf files.  Files without the extension .dxx and .dxf (lower case) will not be processed.   
**dx_extract_WATCH** folder is used for these files, resulting attout.txt and attout.xlsx files are created in **dx_attout** & **dx_xlsx**    
Successful files will be moved to **dx_pass** & a copy made to the **dx_dxf4insert** folder pending later insert operations.  
Attribute data will be extracted as an attribute.txt file matching AutoKADs attribute export & also as an xlsx.
The first column of the xlsx contains the zoom to object command for that entity.  Paste into the CAD command line and press
return twice.  This Magic Margin will have future use.  The xlsx2txt script will ignore the A column; it can be used for notes.   

## USING dx_insert (-h -l)
`dx_insert` takes an attout.txt formatted file (from AutoKADs attout/export attributes or dx_extract) and merges this data back into a dxf file of the same name (and the same meta-data of course)   
**dx_insert_WATCH** is for the attribute.txt file.  Must have the same name as the dxf other than the extension.   
**dx_dxf4insert** is for the .dxf file intended for attribute replacement.     
During attribute replacement a temporary file will be created in dx_dxf4insert with a .tmp extension.  The updated file will replace the original .dxf.
The attribute .txt file will be moved to the pass folder on successful completion, however, the .dxf will remain in dx_dxf4insert pending further updates.   

## USING dx_xls2txt (-h -l -i)
`dx_xlsx2txt` takes xlsx files created with dx_extract and converts these to attout.txt format.  This in turn can be inserted with dx_insert or imported with AutoKADs ATTIN command.   
**dx_xlsx2txt_WATCH** is for the .xlsx files produced by dx_extract. File must have an .xlsx extension.  
**dx_attin** is the destination for the converted file.   
attin/attout files should always have .txt extensions and Windows format new lines.   
The .xlsx file produced by dx_extract has the first 2 rows and the first column as margin space.  These must remain & can be used for comments.
In the future, the left most column might be used to flag a row for further processing if it contains the relevant command.   
-i option changes the insert path for source and destination to match the insert WATCH folder.  Running in this mode allows the xlsx conversion to be followed by insertion without
having to move the processed attout file to the insert WATCH folder.    

### USING dxMagicbuilder & Installing dxMagic
dxMagic is just a collection of Perl scripts. The build script dxMagicbuilder.pl will create an example directory structure, making this available as SAMBA shares. A default user 'alice' will be created with user defined password.  Excel creation requires the *Excel::Writer::XLSX* module to be installed; modules are added by the build script.  *Spreadsheet::Read* is required for the xlsx read subroutine. This also requires  *Spreadsheet::ParseXLSX*. Once Spreadsheet read is installed, the `xlscat` command is available and very handy for teseting.
`xlscat -i` is particularly handy to show a summary of sheet names and size only.
For Windows, install Strawberry Perl; use cpan to install cpanm,`cpan App::cpanminus`,  then install the modules with the cpanm command, for example `cpanm Excel::Writer::XLSX`.  Edit the script headers to create the necessary folders (with appropriate slash separators for your OS).  dxMagicbuilder is an install script to setup a test environment with SAMBA shares.
dxMagicbuilder is a hacked version of the dbdotcad build script.  Its a mess.
For testing via an ssh session try using screen.  `screen`, `ctrl a + c` creates a new screen, `ctrl a + d` detaches the screen session leaving the processes running.
`ctrl a + n` for next screen, `ctrl a + p` for previous screen.  `screen -ls` to list screen sessions, reconnect with `screen -r <screen-shown-via-ls>`  

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
The data key is called a TAG and the value can display as text on a drawing layer or be hidden. The TAG name cannot contain spaces and is normalised to upper case. Think of creating a block with attribute meta-data as creating a data object. Adding an attribute adds another key/value pair to the block object.  

Attribute values can be automatically populated with CAD variables such as the drawing title, date, file name, user, etc.  The default value is populated when the block is inserted.  When attributes are manually populated, a prompt can be issued to remind the user what is required for an attribute value on an attribute by attribute basis.  The value can also be a predetermined constant.   

Drawing text is graphical and part of the drawing.  Attribute text is abstracted from the drawing and can be replaced without changing the graphical part of the design.  Attribute text can be turned into drawing text with the `BURST` command.  BURST text will remain as a static part of the drawing.   

Blocks are referenced by AutoKAD automatically adding an entity HANDLE that will be unique for that drawing.  
DXF format associates the HANDLE reference with group code 5. The HANDLE is a text string of up to 16 hexadecimal digits.  The HANDLE is a hard reference and will not be changed by purge operations.  
Copying a block, even from another drawing will result in the HANDLE entity being replaced.  Every block/object has a reserved field for the BLOCKNAME.   

Blocks can be used to created classes of objects to describe the designers environment.  A sensible implementation would use the BLOCKNAME to indicate the class it belongs to.  Adding a version number to the BLOCKNAME is considered best practice.
The HANDLE is unique only to the drawing and has no scope beyond the drawing in which it resides.  In practice this means the HANDLE and BLOCKNAME can be duplicated in completely different drawings.  With careful naming conventions it is possible to use this mechanism to reference an object with a combination of HANDLE and document identifier so that it is unique for any document within an enterprise.   When creating attribute data, SystemVariable dwgname contains the drawing file name, SystemVariable dwprefix contains the drawing file name path.   

Full AutoKAD (2004 and higher) has express tools to perform attribute export/import (Express > Blocks > Export/Import Attribute Information, commands are `ATTOUT`/`ATTIN`).  Express tools installed by default from 2008 on wards.  `ATTOUT` produces a tab deliminated text file with the first row always containing the headings (TAGs).  The first two columns are always HANDLE and BLOCKNAME.  The handle entity has a leading single quote added.  Empty values are blank.  Missing values (think of cells in a row) will be present if the block has no corresponding TAG (column).  Missing values in a column are packed with <>.  ATTOUT only works with level one blocks (i.e. not nested).   

AutoKAD light and ProgKAD do not have the attribute import/export tool; however, the earlier `ATTEXT` command also present in full AutoKAD is available.  `ATTEXT` can be used to produce a comma or space delimited file but for these formats it is necessary to provide a template file.  Obviously the template would have to be updated every time a new block with different tags is created i.e. new tags or object classes require template changes.  The BL:HANDLE will be required as a reference to import the data back into the drawing.  The DXX option provides a  file output which is a fragment of the DWG format.  DXX is more flexible with no need for a template but parsing of the resulting file will be required.  There are differences in the resulting data between ProgKAD and AutoKAD but the objective is to provide transparent parsing of dxx/dxf. The Design Web Format is out of scope.  DWG TrueView (a free utility) will save to different versions of DWG and will export DWF & DWFx but will not save to DXF.  TrueView will open DXF for viewing and save to DWG.

Auto & Prog will save DWG to DXF but it is best practice to use the `AUDIT` command to clean up the drawing prior to saving to DXF.  `PURGE` & `OVERKILL` are also useful for removing unwanted drawing components.  AutoKAD has been known to save into DXF and then not be able to load the file it just saved, without AUDITing first, Error in STYLE Tables with Invalid symbol table record names are common. The `ATTEXT` command (same as the earlier `DDATTEXT` command) can be used to save a selected area on a drawing in either MODEL or PAPER space.
The `EXPORT` command (or File > Export) also has an option to save as DXX Extract (\*.dxx).  Note that the Export Metafile option is for saving as Windows graphical Metafiles (\*.wmf), not attribute metadata.

Auto/ProgKAD has two different view modes.  MODEL space is where the design work is actually done and has defined units of measure to a defined resolution.  A viewport is created into the MODEL space, usually scaled to fit a given paper size.  Typically a drawing boarder is placed within the PAPER space so the viewport shows the desired area of the model scaled within the boarder.  The boarder can contain blocks and will usually contain attribute data to show the document title, versions & revisions.  The `ATTEXT` and `EXPORT`  functions can only select and create a \*.dxx export file from the drawing space visible at the time.  Working in dxf or saving the drawing as dxf file is for a whole drawing.  Parsing a \*.dxf file will result in all the meta-data from both MODEL and PAPER space being extracted.

To display the block handle value from the drawing use the command use Lisp `(entget (car (entsel)))` and look for group 5.  
To list objects in a block definition use `BLOCK?` if Express Tools area available.      
To zoom to a block by handle value, `_ZOOM`, Select the Object option. When prompted to Select Objects, enter `(HANDENT "HandleID")`, press ENTER to Zoom to this object.  In practice this reduces to: `Z ENTER O ENTER (HANDENT"ABCD") ENTER ENTER`.  An object can be selected in a similar way with the `_SELECT` command.
A hyphen before a command will avoid the dialog box. An asterisk before a block name will insert it exploded. `-insert:*MyBlock`  
Command strings require a different syntax, for example zoom extents together becomes `(command "zoom" "e")`   
To zoom to a known object with handle entity 84E9, with a sinle command line becomes `(COMMAND "ZOOM" "OBJECT" (HANDENT"84E9"))`, then 2 x ENTER.  This command was added to the COMMAND column in the extracted spread sheet as a handy way of finding the entity in the drawing by pasting this into Auto/ProgKADs command prompt.      

## Attribute association and inheritance

It is a common requirement to associate one block with another where the parent block may have a unique serial/equipment/system/host name.  For example, a connector may be represented by a block which is part of i.e. associated with, a board or card also represented by a block.  That card fits into a chassis also represented by a block which in turn is fitted in a rack...  In the real world objects tend to nest in a parent/child way so the attribute definitions needs to be constructed to allow inherited values so some of the parent DNA can be found in its children.

To track associations it is necessary to provide an attribute to take the value of the identifier from the parent IN A DIFFERENTLY NAMED FIELD.  It’s best practice to include the block name within tag name for this attribute.  CAD properties will show all the attribute tag names so the tag names of parent and child need to easily identified for copy and paste operation.  

Making the association is simple.  Quick properties is your friend.  Select the parent block and one or more children.  Right click to access quick properties or the QP command.  QP window will appear by simply selecting blocks if QPMODE is 1 (can be toggled with ctrl + shift + p).  Select Block reference from the drop down if other choices are available.  Now it’s possible to copy the parent attribute value to the children and see if they are not all equal (shows as \*VARIES\*).  It’S possible to customise which properties are visible in QP.

Example: There is an equipment chassis with an asset number that takes several sub assemblies. The asset number is recorded in a attribute field called `asset_no`.  As it may be necessary to find which assemblies have been fitted to each chassis then the asset_no needs to be copied to the assembly blocks by creating another attribute in the 'children' blocks called `passet`.  Insert the parent block, adding the asset number.  Select parent and all sub assembly blocks then open QP and the Block references will show the asset_no value which can be copied in one paste operation to the (all) the fields named `passet`, associating the equipment chassis with the sub assemblies.

# Binary DXF
Binary DXF files are not currently supported but preserve all of the accuracy in the drawing database. ProgKAD will save a binary DXF from the save as drop down.  
AutoKAD also provides the binary DXF option from File, Save As...
then it is necessary to use the Tools drop down, select Option... DXF Options tab and select BINARY    
Binary DXF was introduced in AutoKAD release 10.  The `DXFOUT` command will also open the Save As... dialogue.
A binary DXF file begins with a 22-byte sentinel used to identify the format when the file is loaded.
Currently **dx_extract** checks the file header and will print an warning if `/^AutoCAD\sBinary\sDXF/` is found.

# Future utils
The DWG Compare free msi add-in for AutoCAD (adds to ribbon Add-ins menu or the ribbon in the Classic toolbar as a plug-ins) presents as text and visual differences.
It would be nice to have a block attribute compare between drawings or drawing and database.   
