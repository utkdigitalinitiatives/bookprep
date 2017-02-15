# bookprep

rearranges local digitized book structure,
(files and directories), to islandora book_batch form
also creates derivatives for jp2, ocr, hocr

requirements:
* version 3.02, 3.03, or 3.04 of tesseract
* kdu_compress and kdu_expand
* xmllint

 will convert tifs to jp2 or jp2 to tifs
 will also convert jp2s to tif make ocr
 and then delete the tif if the object file is meant to be a jp2

 makes OCR and HOCR, corrects the tesseract 3.04 action of the HOCR step also making OCR.

use:  run as a shell command with two parameters

directory= the directory below bookprep that contains all the volumes of your books

objectfiletype=  the type of the OBJ file you want to ingest, jp2 or tif

./bookprep.php directory objectfiletype

./bookprep.php  issues_dir jp2

 usage:
./bookprep.php version
  --
./bookprep.php test collectiondirectory
  -- check if valid files exist in the right places

 ./bookprep.php collectiondirectory to-image-type



start with standard directory form for books

[a collection directory]
--- [with item directories] inside of it
--- and xml files for the items outside of the item directories
------ page image files are all inside of each item directory

filenames of pages have to be separated with at least one "_"
as in:
roth_001.tif
or
comm_2005jan_0001.tif
or
0012_002345_000211_001.tif

the item directories and xml filenames have one less section than the
image file names.

the page files have an integer number ( with leading zeros)
representing the sequence.

if the files and directories are not arranged  and named like this,
the script will not work.


read parameters from command line
 cover these states:
 from  to
 ========
 tif tif
 tif jp2
 jp2 tif
 jp2 jp2

( the from type will be detected from the file that is already there)

change into collection directory,

find an item directory and a xml file that goes with it.
also copy xml file with new name DC.xml or MODS.xml
( will be detected from the existing namespace in the xml)
into item directory.

.... processing image files....

determine "fromtype" files already in item directory

make a directory named 1 or 2 or 3, etc. for page sequence

make a MODS.xml for the page
with title being read from orig xml in directory above
like (title : page 2) and put it in page dir

move item into the page directory

if it is a JP2, make a tif
if OCR.txt exists move to page directory
else make OCR and HOCR for the moved file

tif is deleted if not totype
