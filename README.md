# dxMagic
Proof of concept DXF and DXX file parser

dxMagic is a proof of concept attempt to take dxx output and turn it into a ATTOUT formatted text file.  With little modification it is possible to extend dxx parsing to dxf files.  This makes it possible to extract attribute data directly from the drawing file without the need to open it in a CAD package.   

### Looking for a CAD tutorial?
Please exucuse the alternative spellings; they are intended to prevent search engines picking up this document. Some AutoKAD commands will be explained but this is not a CAD tutorial. There are lots of good tutorials for AutoKAD. This is not one of them.

## AutoKAD metadata - a concise explanation for programmers

AutoKAD can group graphical lines and key/value data by creating a block.  This allows for easy duplication of commonly used item;, for example, a block can be created for a chair and re-used several times in an office layout.  The chair block can optinally contain multiple key/value pairs of metadata, designed to descible the chair or furniture class object.
The data key is called a TAG and the value can display as text on a drawing layer or be hidden. The TAG name cannot contain spaces and is normalised to upper case. Think of creating a block with metadata as creating a data object.   

A key value pair is known as an attribute.  Values can be automatically populated with CAD variables such as the drawing title, date, filename, etc.  The default value is populated when the block is inserted.  When attributes are populated, a prompt can be issued to remind the user what is required on an attribute by attribute basis.  The value can also be a constant.   

Drawing text is graphical and part of the drawing.  Attribute text is abstracted from the drawing and can be replaced without changing the graphical part of the design.  Attribute text can be turned into drawing text with the `BURST` command.  BURST text will remain as a static part of the drawing.   

Blocks are referenced by AutoKAD automatically adding an entity HANDLE that will be unique for that drawing.  
DXF format associates the HANDLE reference with group code 5. The HANDLE is a text string of up to 16 hexadecimal digits.  The HANDLE is a hard reference and will not be changed by purge operations.  
Copying a block, even from another drawing will result in the HANDLE entity being replaced.  Every block/object has a reserved field for the BLOCKNAME.   

Blocks can be used to created classes of objects to describe the designers environment.  A sensible implementation would use the BLOCKNAME to indicate the class it belongs to.  Adding a version number to the BLOCKNAME is considered best practice.
The HANDLE is unique only to the drawing and has no scope beyond the drawing in which it resides.  In practice this means the HANDLE and BLOCKNAME can be duplicated in completely different drawings.  With careful naming conventions it is possible to use this mechanism to reference an object with a combination of HANDLE and document identifier so that it is unique for any document within an enterprise.   

Full AutoKAD (2004 and higher) has express tools to perform attribute export/import (Express > Blocks > Export/Import Attribute Information, commands are `ATTOUT`/`ATTIN`).  Express tools installed by default from 2008 onwards.  `ATTOUT` produces a tab deliminated text file with the first row always containing the headings (TAGs).  The first two columns are always HANDLE and BLOCKNAME.  The handle entity has a leading single quote added.  Empty values are blank.  Missing values will be present if the block has no corresponding TAG.  Missing values in a colunm are packed with <>.  ATTOUT only works with level one blocks (i.e. not nested).   

AutoKAD light and ProgKAD do not have the attribute import/export tool; however, the earlier ATTEXT command also present in full AutoKAD is available.  ATTEX can be used to produce a comma or space deliminated file but for these formats it is necessary to provide a template file.  Obviously the template would have to be updated everytime a new block with different tags is created i.e. new tags or object classes require template changes.  The BL:HANDLE will be required as a referencec to import the data back into the drawing.  The DXX option provides a  file output which is a fragment of the DWG format.  DXX is more flexible with no need for a template but parsing of the resulting file will be required.  There are differences in the resulting data between ProgKAD and AutoKAD but the objective is to provide transparent parsing of dxx/dxf.   
