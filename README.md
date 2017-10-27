# Bookprep

## Introduction

This CLI PHP script rearranges local digitized book structure, files, and directories to islandora book_batch form
also creates derivatives for jp2, ocr, hocr.

1. At start up, does a system check and will list requirements and exit if they do not exist.
2. The given directory is checked for files in the proper format and a list of errors will be printed and the program will exit if the format is wrong.
3. When the input files are properly formatted, bookprep will:
  - remove misc housekeeping files from other programs, currently `".DS_Store, ._*"`
  - convert tifs to jp2 or jp2 to tifs
  - convert jp2s to tif and make ocr then delete the tif if the object file is meant to be a jp2
  - make OCR and HOCR, corrects the tesseract 3.04 action of the HOCR step also making OCR.


## Requirements

1. Linux command line on server
2. Tesseract - version 3.02, 3.03, or 3.04 
3. KDU_expand and kdu_compress
4. ImageMagick (convert)
5. xmllint

## Use

Run as a shell command with two parameters.
1. directory= the directory below bookprep that contains all the volumes of your books
2. objectfiletype=  the type of the OBJ file you want to end up with to ingest, jp2 or tif

Example:

./bookprep.php directory objectfiletype

./bookprep.php  issues_dir jp2

Locally, we run this in a screen session on a group of books, overnight for example, and might have several running at the same time as an ingest of a previous batch of books.

## Details

Start with standard directory form for books.

**Example of what it should look like before running Bookprep**
```terminal
example/
├── example-vol1-no1
│   ├── example-vol1-no1_0001.tif
│   ├── example-vol1-no1_0002.tif
│   ├── example-vol1-no1_0003.tif
│   └── example-vol1-no1_0004.tif
├── example-vol1-no1.xml
├── example-vol1-no2
│   ├── example-vol1-no2_0001.tif
│   ├── example-vol1-no2_0002.tif
│   └── example-vol1-no2_0003.tif
├── example-vol1-no2.xml
├── example-vol2-no1
│   ├── example-vol2-no1_0001.tif
│   ├── example-vol2-no1_0002.tif
│   ├── example-vol2-no1_0003.tif
│   ├── example-vol2-no1_0004.tif
│   └── example-vol2-no1_0005.tif
└── example-vol2-no1.xml
```

[a collection directory]
--- [with item directories] inside of it
--- and xml files for the items outside of the item directories
------ page image files are all inside of each item directory

Filenames of pages have to be separated with at least one "_",

as in:

roth_001.tif

or

comm_2005jan_0001.tif

or

0012_002345_000211_001.tif

The item directories and xml filenames have one less section than the
image file names.

The page files have an integer number ( with leading zeros)
representing the sequence. This is separated and coverted to an integer to be the page number.

If the files and directories are not arranged  and named like this,
the script will not work. It should exit and give alist of what is not formatted correctly, but there are no garantees. Keep a copy of the directory you start with in case you have to stop part way through.

The script makes a MODS.xml for the page with title being read from item xml in directory above
like (title : page 2) and puts it in each page directory.

**Example of directory structure after bookprep**

This example is only displaying one of the 3 subdirectories. The others should look similar.
```terminal
example/
├── example-vol1-no1
│   ├── 1
│   │   ├── HOCR.html
│   │   ├── MODS.xml
│   │   ├── OBJ.tif
│   │   └── OCR.txt
│   ├── 2
│   │   ├── HOCR.html
│   │   ├── MODS.xml
│   │   ├── OBJ.tif
│   │   └── OCR.txt
│   ├── 3
│   │   ├── HOCR.html
│   │   ├── MODS.xml
│   │   ├── OBJ.tif
│   │   └── OCR.txt
│   ├── 4
│   │   ├── HOCR.html
│   │   ├── MODS.xml
│   │   ├── OBJ.tif
│   │   └── OCR.txt
│   └── MODS.xml
├── example-vol1-no1.xml
├── example-vol1-no2
│   └── ...
├── example-vol1-no2.xml
├── example-vol2-no1
│   └── ...
└── example-vol2-no1.xml
```
## Maintainers

* [Paul Cummins](https://github.com/pc37utn)

## Authors

* [Paul Cummins](https://github.com/pc37utn)

## Development

Pull requests are welcome, as are use cases and suggestions.

## License

[GPLv3](http://www.gnu.org/licenses/gpl-3.0.txt)
