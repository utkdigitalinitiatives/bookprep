#!/usr/bin/php
<?php

/*
 bookprep collectiondirectory to-image-type 
 20141205

 start with standard directory form for books
 [a collection directory]
 --- [with item directories] inside of it
 --- and xml files for the items outside of the item directories
 ------ page image files are all inside of each item directory

 filenames have to be separated with at least one "_"
 as in:
 roth_001.tif
or
 comm_2005jan_0001.tif
or
 0012_002345_000211_001.tif

the item directories and xml filenames have one less section than the
image file names.
the page files have an integer number ( with leading zeros) representing the sequence.

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
 */

//------functions------------------- 
function isDir($dir) {
  $cwd = getcwd();
  $returnValue = false;
  if (@chdir($dir)) {
    chdir($cwd);
    $returnValue = true;
  }
  return $returnValue;
}

function listFiles( $from = '.') {
  if(! is_dir($from)) return false;
  $files = array();
  $dirs = array( $from);
  while( NULL !== ($dir = array_pop( $dirs))) {
    if( $dh = opendir($dir)) {
      while( false !== ($file = readdir($dh))) {
        if( $file == '.' || $file == '..') continue;
        $path = $dir . '/' . $file;
        if( is_dir($path)) $dirs[] = $path;
        else $files[] = $path;
      }// end while
      closedir($dh);
    }//end if
  }// end if
  return $files;
}


function colldirexists($rdir) {
  // exit if no file on command line
  if ((!isset($rdir))||(empty($rdir))) {
    print "*** no directory name given ***, exiting... \n";
    $rdir='';
  }
  if (!isDir($rdir)) {
    print "*** directory name does not exist ***, exiting... ";
    $rdir='';
  }
  print "******** dir=$rdir\n\n";
  return $rdir;
}

function getseqdir($base) {
    // count underscores in filename
    $numsep=substr_count($base, "_");
    if (!$numsep) continue; 
    // break filename on underscores
    $allstr=explode("_",$base);
    if ($numsep==1) {
      // two part name- dir must be parts 0
      $seq=$allstr[1];
      $dirname=$allstr[0];
    }
    elseif ($numsep==2) {
      // three part name- dir must be parts 0,1
      $seq=$allstr[2];
      $dirname=$allstr[0].'_'.$allstr[1];
    }
    elseif ($numsep==3) {
      $seq=$allstr[3];
      // four part name- dir must be parts 0,1,2
      $dirname=$allstr[0]."_".$allstr[1]."_".$allstr[2];
    }
    // convert seq to integer
    $seq=$seq*1;
    //if (($seq>=1)&&($seq<=2000)) print "seq = $seq\n";
    // check for dir already there
    $seqdir=$dirname.'/'.$seq;
  return $seqdir;
}
function getdirname($base) {
    // count underscores in filename
    $numsep=substr_count($base, "_");
    if (!$numsep) continue; 
    // break filename on underscores
    $allstr=explode("_",$base);
    if ($numsep==1) {
      // two part name- dir must be parts 0
      $seq=$allstr[1];
      $dirname=$allstr[0];
    }
    elseif ($numsep==2) {
      // three part name- dir must be parts 0,1
      $seq=$allstr[2];
      $dirname=$allstr[0].'_'.$allstr[1];
    }
    elseif ($numsep==3) {
      $seq=$allstr[3];
      // four part name- dir must be parts 0,1,2
      $dirname=$allstr[0]."_".$allstr[1]."_".$allstr[2];
    }
    // convert seq to integer
    $seq=$seq*1;
    if (($seq>=1)&&($seq<=2000)) print "seq = $seq\n";
    // check for dir already there
    $seqdir=$dirname.'/'.$seq;
    if (!isDir($seqdir)) {
      mkdir($seqdir);
      print "made seqdir= $seqdir \n";
    }  
  return $dirname;
}

function getmeta($xmlfile) {
  $meta='MODS';
  // check for kind of metadata, DC or MODS
  $xml = file_get_contents("$xmlfile");
  $sxe = new SimpleXMLElement($xml);
  $namespaces = $sxe->getDocNamespaces(TRUE);
  // mods 3.2
  if (isset($namespaces['mods'])) $meta="MODS";
  // mods 3.5
  if (isset($namespaces[''])) $meta="MODS";
  if (isset($namespaces['dc'])) $meta="DC";
  return $meta;
}

function gettitle($xmlfile,$meta) {
  $xml = file_get_contents("$xmlfile");
  $sxe = new SimpleXMLElement($xml);
//  $namespaces = $sxe->getDocNamespaces(TRUE);
  // shortened choice-- DC or not
//  if (isset($namespaces['dc'])) $booktitle = $sxe->title;
  if ($meta=='DC') $booktitle = $sxe->title;
  else $booktitle = $sxe->titleInfo->title;
  return $booktitle;
}
//------------- begin main-----------------

$rdir=$numsep=$xnew=$new=$tif='';

//get parameters from command line
$rdir=$argv[1];
$totype=$argv[2];

// ---------------
if (colldirexists($rdir)!=$rdir) {
  print "usage: bookprep.php directoryname destination-type:(tif|jp2)\n";
  exit();
}
if (!$totype) {
  print "usage: bookprep.php directoryname destination-type:(tif|jp2)\n";
  print "Error **  missing type*** \n";
  exit();
}
$dir=$rdir;
// change to dir and read filenames
chdir($dir); 
$dfiles = listFiles(".");
// first loop to read sub directories of items
foreach ($dfiles as $dfil) {
  $dirname=$seq=$seqdir=$xbase=$base=$xnew=$new=$tfile=$tnew='';
  // eliminate the dot directories
  if (($dfil=='.')||($dfil=='..')) continue;
  print "dfil=$dfil \n";
  //check extension
  $end = substr($dfil, -4);
  if ($end=='.xml') {
    // get basename
    $xbase=basename($dfil,'.xml');
    // check for kind of metadata, DC or MODS
    $meta=getmeta($dfil);
    // check for matching item directory
    if (!isDir($xbase)) {
      print "Error ***  item/metadata mismatch ***\n";
      exit();
    }
    //make new location
    $xnew='./'.$xbase.'/'.$meta.'.xml';
    if(!file_exists($xnew)) copy($dfil,$xnew);
    print "copying: $dfil \n  to $xnew\n";
  }// end if xml
  elseif ($end=='.jp2') {
    $fromtype='jp2';
  }
  elseif ($end=='.tif') {
    $fromtype='tif';
  }
  else $fromtype='';
  if (($end=='.jp2') || ($end=='.tif')) {
    // get basename
    $base=basename($dfil,$end);
    $seqdir=getseqdir($base);
    $dirname=getdirname($base);
    // find seq
    $s=explode('/',$seqdir);
    $seq=$s[1];
    $newdir='./'.$seqdir;
    $new='./'.$seqdir."/".'OBJ'.$end;
    // what is xbase xml of this image
    $thisxml=getdirname($base).".xml";
    // get booktitle specific to this image
    $booktitle=gettitle($thisxml,$meta);
    // make mods.xml
    $pagexml=<<<EOL
<?xml version="1.0" encoding="UTF-8"?>
<mods:mods xmlns:mods="http://www.loc.gov/mods/v3" xmlns="http://www.loc.gov/mods/v3">
  <mods:titleInfo>
    <mods:title>$booktitle : page $seq</mods:title>
  </mods:titleInfo>
</mods:mods>
EOL;
    $mfile=$seqdir."/"."MODS.xml";
    file_put_contents($mfile, $pagexml);
    if(!file_exists($new)) rename($dfil,$new);
    print "renaming:  $dfil \n   to : $new\n";
    // also send existing txt file there
    $tfile='./'.$dirname.'/'.$base.'.txt';
    $tnew='./'.$seqdir."/".'OCR.txt';
    if (is_file($tfile)) {
       rename($tfile,$tnew);
    }
    // change into new page dir, remembering previous
    $cwd = getcwd();
    chdir($newdir);
    // do conversion if needed
    if (($fromtype=='tif')&&($totype=='jp2')) {
      $args = 'Creversible=yes -rate -,1,0.5,0.25 Clevels=5';
      $convertcommand="kdu_compress -i OBJ.tif -o OBJ.jp2 $args ";
      exec($convertcommand);
    }// end if tif2jp2
    if ($fromtype=='jp2') {
      // create tif from jp2
      $convertcommand="kdu_expand -i OBJ.jp2 -o OBJ.tif ";
      exec($convertcommand);
    }// end if fromtype=jp2
    // handle ocr
    if(is_file("./OCR.txt")) {
      print "OCR already exists\n";
    }
    else {
      // create OCR
      print "creating OCR.. \n";
      $tesscommand="tesseract OBJ.tif OCR -l eng";
      exec($tesscommand);
      //create HOCR
      print "creating HOCR.. \n";
      $tesscommand="tesseract OBJ.tif HOCR -l eng hocr";
      exec($tesscommand);
    }
    // if dest is tif
    if ($totype=='tif') {
      // delete the OBJ.jp2
      if (is_file('OBJ.jp2'))  exec("rm -f OBJ.jp2");
    }// end if totype is tif
    // if the OCR and HOCR are there, delete the tif, unless it is the totype
    if ((is_file("OCR.txt"))&&(is_file("HOCR.html"))&&($totype!='tif'))  exec("rm -f OBJ.tif");
    // change back
    chdir($cwd);
    //
  }//end else is tif
  //chdir('..');
}//end foreach
unset($dfiles);
?>

