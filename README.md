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
