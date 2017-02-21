#!/usr/bin/php
<?php
/*
 * bookprep.php
 * 20141205
 * re-arrange files and directories and make derivatives to
 * to used as a directory ingest into Islandora Solution Pack Book
 * 20170220
 * add test mode before run
*/

//------functions-------------------
/*
 * chktess  checks if an install of tesseract is available
 *
*/
function chkTess() {
  global $errorlist;
  $returnValue = '';
  $out=`tesseract -v 2>&1`;
  if (strstr($out,'tesseract 3.')) {
    $returnValue = true;
  }
  else {
    $err="error: Tesseract not available";
    array_push($errorlist, "$err");
  }
  return $returnValue;
}
/*
 * chkKDU  checks if an install of tesseract is available
 *
*/
function chkKDU() {
  global $errorlist;
  $returnValue = '';
  $out=`kdu_compress -v 2>&1`;
  if (strstr($out,'version v6')) {
    $returnValue = true;
  }
  else {
    $err="error: kdu_compress/expand not available";
    array_push($errorlist, "$err");
  }
  return $returnValue;
}
/*
 * chkConvert  checks if an install of Imagemagick convert is available
 *
*/
function chkConvert() {
  global $errorlist;
  $returnValue = '';
  $out=`convert -version 2>&1`;
  if (strstr($out,'ImageMagick')) {
    $returnValue = true;
  }
  else {
    $err="error: ImageMagick convert not available";
    array_push($errorlist, "$err");
  }
  return $returnValue;
}
/*
 * chkConvert  checks if an install of Imagemagick convert is available
 *
*/
function chkXmllint() {
  global $errorlist;
  $returnValue = '';
  $out=`xmllint --version 2>&1`;
  if (strstr($out,'xmllint: using')) {
    $returnValue = true;
  }
  else {
    $err="error: xmllint not available";
    array_push($errorlist, "$err");
  }
  return $returnValue;
}
/*
 * chkMaindir  checks if the main container directory exists
 * and adds an error if it does not
 *
*/
function chkMaindir($rdir) {
  global $errorlist;
  $returnValue = false;
  if (isDir($rdir)) {
    $returnValue = true;
  }
  else {
    $err="error: Main directory does not exist.";
    array_push($errorlist, "$err");
  }
  return $returnValue;
}
/*
 * chkMeta  checks the metadata file names against directories
 *
 *
*/
function chkMeta($rdir) {
  global $errorlist;
  $xbase='';
  $xmlcount=0;
  $cwd = getcwd();
  chdir($rdir);
  $dfiles = listFiles(".");
  // first loop to read all existing files
  foreach ($dfiles as $dfil) {
    $end = substr($dfil, -4);
    if ($end=='.xml') {
      $xmlcount++;
      //print "testing metadata file: $dfil \n";
      // get basename
      $xbase=basename($dfil,'.xml');
      // check for matching item directory
      if (!isDir($xbase)) {
        $err="error: xml does not have matching directory:$dfil\n";
        array_push($errorlist, "$err");
      }
    }//end if xml
    if ($xmlcount==0) {
      $err="error: missing xml \n";
      array_push($errorlist, "$err");
    }
  }//end foreach
  // checking directories to see if they have matching metadata
  $out=`ls -d1`;
  $mdirs=explode('/\n',$out);
  foreach ($mdirs as $d) {
    if (!file_exists($d.'.xml')) {
      $err="error: metadata mismatch-- missing directory:$d";
      array_push($errorlist, "$err");
    }
  }
  chdir($cwd);
  return;
}
/*
* isDir  checks if a directory exists
* and changes into it and changes back to original
*/
function isDir($dir) {
  $cwd = getcwd();
  $returnValue = false;
  if (@chdir($dir)) {
    chdir($cwd);
    $returnValue = true;
  }
  return $returnValue;
}
/*
* colldirexists  checks for directory that holds collection,
* returns error if not there.
*/
function colldirexists($rdir) {
  // exit if no file on command line
  if ((!isset($rdir))||(empty($rdir))) {
    print "*** no directory name given ***, exiting... \n";
    $rdir='';
  }
  //print "******** dir=$rdir\n\n";
  return $rdir;
}
/*
* listFiles  returns an array of all filesnames,
*  in a directory and in subdirectories, all in one list
*
*/
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
/*
* getNumSep  returns an integer for the number of
* underscores in a basename or gives error for file
*/
function getNumSep($base) {
  global $errorlist;
  // count underscores in filename
  $numsep=substr_count($base, "_");
  if (!$numsep) {
    $err = "error: no underscores: $base";
    array_push($errorlist, "$err");
  }
  if ($numsep>3) {
    $err = "error: too many underscores: $base";
    array_push($errorlist, "$err");
  }
  return $numsep;
}
/*
* testseq
* by converting seq to integer
*/
function testseq($seq) {
  if (($seq<1)||($seq>2000)) return FALSE;
  return TRUE;
}
/*
* getseqdir  returns an integer for an
* page sequence number on the end of a basename
*/
function getseqdir($base) {
    // count underscores in filename
    $numsep=getNumSep($base);
    //$numsep=substr_count($base, "_");
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
/*
*  getdirname
*  separates filename and returns part
*  that is supposed to be directory name
*/
function getdirname($base) {
    // count underscores in filename
    $numsep=substr_count($base, "_");
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
/*
*  getmeta   returns either MODS or DC
*/
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
/*
* gettitle  retruns the title of a book,
depending on the metadata
*/
function gettitle($xmlfile,$meta) {
  $xml = file_get_contents("$xmlfile");
  $sxe = new SimpleXMLElement($xml);
  if ($meta=='DC') $booktitle = $sxe->title;
  else $booktitle = $sxe->titleInfo->title;
  return $booktitle;
}
//------------- begin main-----------------

$rdir=$numsep=$xnew=$new=$tif=$rep='';
$errorlist = array();
//get parameters from command line
if (isset($argv[1])) $rdir=$argv[1];
else {
  print "usage: bookprep.php directoryname destination-image-type:(tif|jp2)\n";
  print "Error **  missing parameters*** \n";
  exit();
}
if (isset($argv[2])) {
  if (($argv[2]=='tif')||($argv[2]=='jp2')) $totype=$argv[2];
  else {
    print "destination-image-type must be either \"tif\" or \"jp2\"\n";
    print "Error **  missing parameters*** \n";
    exit();
  }
} //end if
else {
  print "usage: bookprep.php directoryname destination-image-type:(tif|jp2)\n";
  print "Error **  missing parameters*** \n";
  exit();
}
// ---------------
if((chkConvert())&&(chkXmllint())&&(chkKDU())&&(chkTess())&&(chkMaindir($rdir))) {
  // running basic system checks
  chkMeta($rdir);
}
if(count($errorlist)>=1) {
  print "**** The following errors exist, please fix and rerun. ***\n";
  foreach($errorlist as $err) {
    print "$err\n";
  }
  print "Bookprep is exiting.";
  exit();
}
print "There are no errors, bookprep will be able to start the processing.";
echo "Continue?: (N or any key to continue) ";
$input=fgetc(STDIN);
if (($input=='n')||($input=='N')) {
  print "Bookprep is exiting.";
  exit();
} //else will continue below
$dir=$rdir;
// change to dir and read filenames
chdir($dir);
$dfiles = listFiles(".");
// first loop to read all existing files
foreach ($dfiles as $dfil) {
  $dirname=$seq=$seqdir=$xbase=$base=$xnew=$new=$tfile=$tnew='';
  // eliminate the dot directories
  if (($dfil=='.')||($dfil=='..')) continue;
  print "current file=$dfil \n";
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
      print " there is no directory to match $dfil\n";
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
    print "Now working with $dirname...\n";
    // find seq
    $s=explode('/',$seqdir);
    $seq=$s[1];
    $newdir='./'.$seqdir;
    $new='./'.$seqdir."/".'OBJ'.$end;
    // what is xbase xml of this image
    $thisxml=getdirname($base).".xml";
    // get booktitle specific to this image
    $booktitle=gettitle($thisxml,$meta);
    // encode entities
    $booktitle=htmlentities($booktitle,ENT_QUOTES,'UTF-8');
    // make mods.xml
    $pagexml=<<<EOL
<?xml version="1.0" encoding="UTF-8"?>
<mods:mods xmlns:mods="http://www.loc.gov/mods/v3" xmlns="http://www.loc.gov/mods/v3">
  <mods:titleInfo>
    <mods:title>$booktitle : page $seq</mods:title>
  </mods:titleInfo>
</mods:mods>
EOL;
// switch contexts to fix syntax highlighting
?>
<?php
    $mfile=$seqdir."/"."MODS.xml";
    print "Writing MODS.xml\n";
    file_put_contents($mfile, $pagexml);
    if(!file_exists($new)) {
      rename($dfil,$new);
      print "renaming:  $dfil \n   to : $new\n";
    }
    else {
      print "$new is already in destination, ok.\n";
    }
    // also send existing txt file there
    $tfile='./'.$dirname.'/'.$base.'.txt';
    $tnew='./'.$seqdir."/".'OCR.txt';
    if (is_file($tfile)) {
       rename($tfile,$tnew);
    }
    // change into new page dir, remembering previous
    $cwd = getcwd();
    print "Changing to directory: $newdir\n";
    chdir($newdir);
    // do conversion if needed
    if (($fromtype=='tif')&&($totype=='jp2')) {
      $args = 'Creversible=yes -rate -,1,0.5,0.25 Clevels=5';
      $convertcommand="kdu_compress -i OBJ.tif -o OBJ.jp2 $args ";
      print "Converting tif to jp2\n";
      exec($convertcommand);
    }// end if tif2jp2
    if ($fromtype=='jp2') {
      // create tif from jp2
      $convertcommand="kdu_expand -i OBJ.jp2 -o OBJ.tif ";
      print "Converting jp2 to tif\n";
      exec($convertcommand);
    }// end if fromtype=jp2
    // handle ocr
    if(is_file("./OCR.txt")) {
      print "OCR already exists\n";
    }
    else {
      // create OCR
      print "Creating OCR.. \n";
      $tesscommand="tesseract OBJ.tif OCR -l eng";
      exec($tesscommand);
      //create HOCR
      print "Creating HOCR.. \n";
      $tesscommand="tesseract OBJ.tif HOCR -l eng hocr";
      exec($tesscommand);
      // remove doctype if it is there using xmllint
      shell_exec("xmllint --dropdtd --xmlout HOCR.hocr --output HOCR.html");
      exec("rm -f HOCR.hocr");
      // delete redundant text file if it exists
      if (is_file('HOCR.txt')) exec("rm -f HOCR.txt");
    }
    // if dest is tif
    if ($totype=='tif') {
      // delete the OBJ.jp2
      if (is_file('OBJ.jp2'))  exec("rm -f OBJ.jp2");
    }// end if totype is tif
    // if the OCR and HOCR are there, delete the tif, unless it is the totype
    if ((is_file("OCR.txt"))&&($totype!='tif'))  exec("rm -f OBJ.tif");
    // change back
    chdir($cwd);
    //
  }//end else is tif
  //chdir('..');
}//end foreach
unset($dfiles);
?>
