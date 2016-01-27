# bookprep

rearranges local digitized book structure,
(files and directories), to islandora book_batch form
also creates derivatives for jp2, ocr, hocr

requirements:
* version 3.02, 3.03, or 3.04 of tesseract
* kdu_compress and kdu_expand
* xmllint

use:  run as a shell command with two parameters

./bookprep.php directory objectfiletype
./bookprep.php  issues_dir jp2
