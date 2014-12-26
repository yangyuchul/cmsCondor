#!/bin/bash

echo "############"
echo "  @ $0 $@"
echo "############"
DColor='\e[39m'         # Default
Black='\e[0;30m'        # Black
Red='\e[0;31m'          # Red
Green='\e[0;32m'        # Green
Blue='\e[0;34m'         # Blue
Purple='\e[0;35m'       # Purple
Cyan='\e[0;36m'         # Cyan

#selfpath=$(cd ${0%/*} && echo $PWD/${0##*/})
#echo $selfpath

if [ "$CMSSW_BASE" == "" ]; then
	echo -e "${Red} Not Found CMSSW_BASE, Please setup CMSSW ${Black}"
	exit
fi

FirstDir=$PWD
origCFG=NULL
dataset=NULL
maxFiles=NULL
XrdOutPATH=NULL
ReturnOutput=True
AutoSubmit=False
AddFiles=""
AddFilesABS=""
ExeFile=""
AddOutFiles=""
function usage() {
	echo "usage: $0 -cfg=<cfg.py> -indata=<dataset> -nfiles=<NumOfFiles;d=1> -xrdout=<XrdPATH;d=NULL> -getout=<True,False;d=True> "
}

function argvPar() {
	for argv in $@
	do
		arg1=`echo $argv | cut -d"=" -f1`
		arg2=`echo $argv | cut -d"=" -f2`
		if [ "${arg1}" == "-cfg"      ]; then origCFG=`echo $(cd $(dirname "$arg2") && pwd -P)/$(basename "$arg2")` ; continue; fi
		if [ "${arg1}" == "-python"   ]; then origCFG=`echo $(cd $(dirname "$arg2") && pwd -P)/$(basename "$arg2")` ; continue; fi
		if [ "${arg1}" == "-py"       ]; then origCFG=`echo $(cd $(dirname "$arg2") && pwd -P)/$(basename "$arg2")` ; continue; fi
		if [ "${arg1}" == "-indata"   ]; then dataset=${arg2}        ; continue; fi
		if [ "${arg1}" == "-dataset"  ]; then dataset=${arg2}        ; continue; fi
		if [ "${arg1}" == "-listfile" ]; then dataset=${arg2}        ; continue; fi
		if [ "${arg1}" == "-nfiles"   ]; then maxFiles=${arg2}       ; continue; fi
		if [ "${arg1}" == "-xrdpath"  ]; then XrdOutPATH=${arg2}     ; continue; fi
		if [ "${arg1}" == "-xrdout"   ]; then XrdOutPATH=${arg2}     ; continue; fi
		if [ "${arg1}" == "-getout"   ]; then ReturnOutput=${arg2}   ; continue; fi
		if [ "${arg1}" == "-submit"   ]; then AutoSubmit=True        ; continue; fi
		if [ "${arg1}" == "-exe"      ]; then ExeFile=${arg2}        ; continue; fi
		if [ "${arg1}" == "-execute"  ]; then ExeFile=${arg2}        ; continue; fi
		if [ "${arg1}" == "-exefile"  ]; then ExeFile=${arg2}        ; continue; fi
		if [ "${arg1}" == "-addfile"  ]; then AddFiles="${AddFiles} ${arg2}"; continue; fi
		if [ "${arg1}" == "-addout"   ]; then AddOutFiles="${AddOutFiles} ${arg2}"; continue; fi
		echo "${Red}UnknowOption $argv Ignored it!${DColor}" 
		echo "UnknowOption $argv Ignored it!" >> $CondorWorkDir/.jobConfigError
	done
}
argvPar "$@"

if [ $# -le 1 ]; then usage; exit;  fi
if [ ! -f $origCFG ]; then usage; exit; fi
if [ "$dataset" == "NULL" ]; then echo "dataset"; usage; exit; fi
if [ "$maxFiles" == "NULL" ]; then 	maxFiles=1 ; fi
if [ "$XrdOutPATH" = "NULL" ]; then ReturnOutput=True ; fi

echo "####################"
echo "CfgFile $origCFG"
echo "InputFiles $dataset"
echo "MaxFiles $maxFiles"
echo "XRDPATH $XrdOutPATH"
echo "ReturnOut $ReturnOutput"
if [ "${AddFiles}" != "" ]; then 
	echo "AddFiles $AddFiles"; 
	for addF in $AddFiles
	do
		if [ ! -e "`readlink -f $addF`" ]; then echo "Not Found $addF"; exit; fi
		addF="$(cd `dirname ${addF}` && pwd)/`basename ${addF}`"
		AddFilesABS="${AddFilesABS} $addF"
	done
fi
echo "####################"



OutROOTNames=""
ThisGURL=""

function dirString() {
   dataStr=${1//\//_D_}
   echo ${dataStr/_D_/} 
}

dataInList=""
if [ -f $dataset ]; then
	dataInList=${PWD}/$dataset
	dasStr=`basename $dataset`
	dasStr=${dasStr/./_}
else
	dasStr=`dirString $dataset`
fi


dateString="`date +"%y%m%d_%H%M%S"`"
CondorWorkDir=$PWD/Condor_${dasStr}_${dateString}
BCondorWorkDir=`basename $CondorWorkDir`
mkdir $CondorWorkDir
mkdir -p $CondorWorkDir/input/src

echo "# `date` ${USER}@`hostname`:${PWD} " > $CondorWorkDir/.jobConfig
echo "$0 $@" >> $CondorWorkDir/.jobConfig


function makeCode() {
	echo "### Make Code"
	cd $CondorWorkDir
cat << EOF > condorRun.sh
#!/bin/bash

echo "### Condor Running \`whoami\`@\`hostname\`:\`pwd\` CONDOR_ID=\${CONDOR_ID} \`date\` "
export MyCondorCluster=\`echo \${CONDOR_ID} | cut -d_ -f1\`
export MyCondorISectionC=\`echo \${CONDOR_ID} | cut -d_ -f2\`
export MyCondorControlN=\$1
export MyCondorMaxFile=\$2
export MyCondorXrd=\$3
export MyCondorOutput=\$4
export MyCondorISection=\`expr \${MyCondorISectionC} + \${MyCondorControlN}\`

echo "MyCondorCluster    \$MyCondorCluster  " 
echo "MyCondorISectionC  \$MyCondorISectionC " 
echo "MyCondorISection   \$MyCondorISection " 
echo "MyCondorControlN   \$MyCondorControlN " 
echo "MyCondorMaxFile    \$MyCondorMaxFile  " 
echo "MyCondorXrd        \$MyCondorXrd      " 
echo "MyCondorOutput     \$MyCondorOutput   " 

export ThisJobStr="\${CONDOR_ID}"

dateSTARTcondor=\$(date +"%s")
FirstDir=\$PWD
mkdir -p \${FirstDir}/condorOut
mkdir -p \${FirstDir}/cmsRunLog

echo "@ PWD \$PWD"
echo "@ ls -alh in \$PWD"
ls -alh
echo ""
echo "@ voms-proxy-info"
voms-proxy-info || grid-proxy-info
echo ""

echo "@ CMSSW setup"
export SCRAM_ARCH=${SCRAM_ARCH}
export VO_CMS_SW_DIR=/cvmfs/cms.cern.ch
source \${VO_CMS_SW_DIR}/cmsset_default.sh
scramv1 project CMSSW ${CMSSW_VERSION}
cd ${CMSSW_VERSION}
tar zxf \${FirstDir}/input.tgz
cd src
eval \`scramv1 runtime -sh\`

ThisInputURL="${ThisGURL}"
cp -rf \${FirstDir}/inputfiles.das .
cat inputfiles.das | awk '{print "'\${ThisInputURL}'"\$1}' > inputfiles.list
echo "@ PWD \$PWD"
echo "@ ls -alh in \$PWD"
ls -alh
echo ""

echo "@ Check InputFiles \$MyCondorISection  \$MyCondorMaxFile"
fileIdx1=\`expr \$MyCondorISection \\* \$MyCondorMaxFile + 1\`
fileIdx2=\`expr \$fileIdx1 + \$MyCondorMaxFile - 1\`
fileIdx=0
echo "@ InputFile Index in inputfiles.list from \$fileIdx1 to \$fileIdx2 \$MyCondorISection \$MyCondorMaxFile"
ThisInputRootFiles=""
ThisNEventsInDAS=""
ThisSumNEventsInDAS=0
for thisInFile in \`cat inputfiles.list\`
do
   ((fileIdx++))
   if [ \$fileIdx -le \$fileIdx2 ] && [ \$fileIdx -ge \$fileIdx1 ]; then
      ThisInputRootFiles="\${ThisInputRootFiles} \${thisInFile}"
      if [ -f inputfiles.das ]; then
         baseThisInFile=\`basename \$thisInFile\`
         thisDASNEvents=\`grep "\$baseThisInFile" inputfiles.das | awk '{print \$2}'\`
         ThisNEventsInDAS="\$ThisNEventsInDAS \$thisDASNEvents"
         ThisSumNEventsInDAS=\`expr \$ThisSumNEventsInDAS + \$thisDASNEvents\`
      fi
   fi
done
if [ "\${ThisInputRootFiles}" == "" ]; then
   echo "   @@@ Error Not Know the InputFiles"
   exit
else
   echo "   @@@ ThisInputRootFiles=\${ThisInputRootFiles}"
fi

echo ""
echo "@ OutNameSet"
for name in \`cat .out_name_file\`
do
	echo "OutName= \$name"
	thisOutDirName=\`dirname \$name\`
	if [ "\$thisOutDirName" != "." ]; then
		mkdir -p \$PWD/\$thisOutDirName
		mkdir -p \${FirstDir}/condorOut/\$thisOutDirName
		if [ ! -d  \$thisOutDirName ]; then
			echo "Error: Can not create  \$thisOutDirName Goto exit "
			exit
		fi
	fi
done


echo ""
echo "### cmsRun"
cmsRunStatus=-99
successTryN=-99
finalCMSRUNtime=-99
ThisCMSRunLogName=""
for tryN in \`seq 1 5\`
do
   echo "@@@ cmsRun Start TryNumber \$tryN \`date\`"
   dateSTARTcmsRun=\$(date +"%s")
   cmsRun cmsRunPSet.py 2>&1 | tee cmsRunLog_\${ThisJobStr}.log
   cmsRunStatus=\$?
	echo ""
   dateENDcmsRun=\$(date +"%s")
   dateDIFFcmsRun=\$((\$dateENDcmsRun-\$dateSTARTcmsRun))
   dateDIFFcmsRun=\$((\$dateDIFFcmsRun / 60))
   finalCMSRUNtime="\$dateDIFFcmsRun"
   if [ "\${cmsRunStatus}" == "0" ]; then
      successTryN=\$tryN
      echo "   @@@ CMSRUNResult TryNumber \$tryN cmsRunSuccess \$cmsRunStatus TimeMinutes \$dateDIFFcmsRun"

      for outRootFile in \`cat .out_name_file\`
		do
			thisOutDirName=\`dirname \$outRootFile\`
	      bRootFile=\`basename \${outRootFile}\`
	      bRootFile=\${bRootFile/.root/}
	      bRootFile="\${bRootFile}_\${ThisJobStr}.root"
	      mv \${outRootFile} \${FirstDir}/condorOut/\${thisOutDirName}/\${bRootFile}
			if [ "\$MyCondorXrd" != "NULL" ]; then
				echo "   @@@ xrdcp \${FirstDir}/condorOut/\${thisOutDirName}/\${bRootFile} \${MyCondorXrd}/\${thisOutDirName}/\${bRootFile}"
				xrdcp \${FirstDir}/condorOut/\${thisOutDirName}/\${bRootFile} \${MyCondorXrd}/\${thisOutDirName}/\${bRootFile}
			fi
		done
  		grep "TrigReport Events total =" cmsRunLog_\${ThisJobStr}.log 
		ThisEventSummary=\`grep "TrigReport Events total =" cmsRunLog_\${ThisJobStr}.log \`
		ThisCMSRunLogName=\`basename cmsRunLog_\${ThisJobStr}.log\`
    	cp cmsRunLog_\${ThisJobStr}.log \${FirstDir}/cmsRunLog/
      break
   else
      echo "   @@@ CMSRUNResult TryNumber \$tryN cmsRunFail \$cmsRunStatus TimeMinutes \$dateDIFFcmsRun Retry \`expr \$tryN + 1\`"
		echo ""
   fi
done

echo ""
echo "# Output "
cd \$FirstDir/condorOut
echo "@find . -type f in \$PWD"
find . -type f
ThisOutFileName=\`find . -name "*.root"\`

cd \$FirstDir
if [ "\$MyCondorOutput" == "NULL" ] || [ "\$MyCondorOutput" == "False" ]; then
   mv \${FirstDir}/condorOut \${FirstDir}/condorOut_remove
   mkdir \${FirstDir}/condorOut
fi

dateENDcondor=\$(date +"%s")
dateDIFFcondor=\$((\$dateENDcondor-\$dateSTARTcondor))
dateDIFFcondor=\$((\$dateDIFFcondor / 60))
echo "# END Condor \`date\`"

cd \$FirstDir
echo "### FinalCondorResult cmsRun \$cmsRunStatus tryNcmsRun \$successTryN cmsRunTime \$finalCMSRUNtime condorRunTime \$dateDIFFcondor"
echo ""

echo ""
echo "#### Run Info"
echo "SummaryRunInformation ThisInputRootFiles= \${ThisInputRootFiles}"
echo "SummaryRunInformation ThisOutFileName= \${ThisOutFileName}"
echo "SummaryRunInformation ThisCMSRunLogName= \${ThisCMSRunLogName}"
echo "SummaryRunInformation ThisNEventsInDAS= \${ThisNEventsInDAS}"
echo "SummaryRunInformation ThisSumNEventsInDAS= \${ThisSumNEventsInDAS}"
echo "SummaryRunInformation ThisEventSummary= \${ThisEventSummary}"
echo ""
EOF
	if [ "${ExeFile}" != "" ]; then
		echo "echo ''" >> condorRun.sh
		echo "### execute ${ExeFile}" >> condorRun.sh
		echo "chmod +x ./`basename ${ExeFile}`" >> condorRun.sh
		echo "ldd ./`basename ${ExeFile}`" >> condorRun.sh
		echo "echo ''" >> condorRun.sh
		echo "./`basename ${ExeFile}`" >> condorRun.sh
	fi

	chmod +x condorRun.sh
}

function stringInFile() {
	numDup=0
	for str in `cat $1`
	do
		bname1=`basename $str`
		dname1=`dirname $str`
		bname2=`basename $2`
		dname2=`dirname $2`
		if [ "${bname1}" == "${bname2}" ] && [ "${dname1}" == "${dname2}" ]; then
			((numDup++))
		fi
	done
	echo $numDup 
}
function removeDupLineInFile() {
	file=$1
	tmpFile="${file}.temp${RANDOM}"
	rm -rf $tmpFile
	touch $tmpFile
	for str in `cat $file`
	do
		if [ "`stringInFile $tmpFile $str`" == "0" ]; then
			echo "$str" >> $tmpFile
		else
			echo " @ DupLine $str, ignored it"
		fi
	done
	mv -f $tmpFile $file
}

function makeCMSSW() {
	echo "### Make CMSSW $CMSSW_VERSION $CMSSW_BASE"
	if [ ! -d $CondorWorkDir/input/src ]; then mkdir -p $CondorWorkDir/input/src; fi
	cd $CondorWorkDir/input/src
	cp $origCFG original_cfg.py

cat << EOF > makePSet
#!/usr/bin/env python
import sys, os
import pickle
sys.path.append('.')
inCfg = str(sys.argv[1]).replace('.py','')
process = __import__(inCfg).process
pklFileName = "cmsRunPSet.pkl"
pklFile = open(pklFileName,"wb")
pickle.dump(process, pklFile)
pklFile.close()
outNameFile = open('.out_name_file','w')
if hasattr(process, 'TFileService'):
`echo -e "\t"`outNameFile.write(process.TFileService.fileName.value()+" \\n")
for modName in process.outputModules_():
`echo -e "\t"`outNameFile.write(getattr(process, modName).fileName.value()+" \\n")
outNameFile.close()
filename = 'cmsRunPSet.py'
psetFile = open(filename, "wb")
psetFile.write("import FWCore.ParameterSet.Config as cms\\n")
psetFile.write("import pickle\\n")
psetFile.write("import os\\n")
psetFile.write("process = pickle.load(open('cmsRunPSet.pkl', 'rb'))\\n")
psetFile.write("iSection = os.environ['MyCondorISection']\\n")
psetFile.write("maxFile = os.environ['MyCondorMaxFile']\\n")
psetFile.write("f = open('inputfiles.list','r')\\n")
psetFile.write("tempRootFiles = f.readlines()\\n")
psetFile.write("f.close()\\n")
psetFile.write("rootFiles = [(rootFile.replace('\\\\n','')) for rootFile in tempRootFiles]\\n")
psetFile.write("nTotalFiles = len(rootFiles)\\n")
psetFile.write("beginN = int(iSection) * int(maxFile)\\n")
psetFile.write("endN = min(beginN + int(maxFile), nTotalFiles)\\n")
psetFile.write("print rootFiles[beginN:endN]\\n")
psetFile.write("process.options = cms.untracked.PSet(wantSummary = cms.untracked.bool(True))\\n")
psetFile.write("process.source.fileNames = rootFiles[beginN:endN]\\n")
psetFile.write("process.maxEvents = cms.untracked.PSet(input = cms.untracked.int32(-1))\\n")
psetFile.close()
EOF
	chmod +x makePSet
	./makePSet original_cfg.py >& makePSet.log
	if [ "${AddOutFiles}" != "" ]; then
		for addout in $AddOutFiles
		do
			echo "$addout" >> .out_name_file
		done
	fi
	removeDupLineInFile ${PWD}/.out_name_file
	numOutFile=`cat .out_name_file | wc -l`
	echo -n "Found OutFileName $numOutFile " 
	for out_name_file in `cat .out_name_file`
	do
		OutROOTNames="${out_name_file} ${OutROOTNames}"
	done
	echo $OutROOTNames
	echo ""
	rm -rf makePSet makePSet.log
	if [ "$numOutFile" == "0" ]; then echo "Not Found Output process.TFileService nor process.outputModules_() in $origCFG" >> $CondorWorkDir/.jobConfigError ; fi
}

function makeList() {
	echo "### Make List searching $dataset "
	cd $CondorWorkDir/
   if [ "${dataset:(-4)}" == "USER" ]; then instance="instance=prod/phys03"; fi
   das_client.py --query="file dataset=${dataset} ${instance} | grep file.name, file.nevents" --limit=0 | grep ".root" >  .inputfiles.das
   sites=`das_client.py --query="site dataset=${dataset} ${instance}" --limit=0`
	sites=${sites//'N/A'/}
	sitesStr=""
	for site in $sites; do sitesStr="$sitesStr $site"; done
	isKISTI=`echo $sites | grep -E "T3_KR_KISTI|cms-se.sdfarm.kr" | wc -l`
	isKNU=`echo $sites | grep -E "T2_KR_KNU|cluster142.knu.ac.kr" | wc -l`
	URL="root://xrootd-cms.infn.it:1194/"
	hn=`hostname`
	if [ "${hn:0:3}" == "ccp" ]; then
		if [ "${isKNU}" != "0" ]; then URL="root://cluster142.knu.ac.kr/"; fi
	fi
	if [ "${isKISTI}" != "0" ]; then URL="root://cms-xrdr.sdfarm.kr:1094//cms/data/xrd/"; fi
	ThisGURL=$URL
	cp -r .inputfiles.das inputfiles.das
	chmod -w .inputfiles.das
	echo "`cat inputfiles.das | wc -l` files `cat inputfiles.das | awk '{NTotalEvents += $2} END{print NTotalEvents}'` events in $sitesStr URL=$URL"
	head -n 1 inputfiles.das
	if [ "`cat inputfiles.das | wc -l`" == "0" ]; then echo "Not Found Files in $dataset" >> $CondorWorkDir/.jobConfigError; fi
}


function makeTAR() {
	cd $CondorWorkDir/input
	ln -s $CMSSW_BASE/lib .
	dataDirs=`find $CMSSW_BASE/src -type d -name "data"`
	for dataDir in $dataDirs
	do
		isCondorDir=`echo $dataDir | grep "Condor_" | wc -l`
		if [ "$isCondorDir" != "0" ]; then continue; fi
   	newDir=${dataDir/"$CMSSW_BASE/src/"/}
   	newDir=`dirname $newDir`
   	mkdir -p src/$newDir
   	ln -s $dataDir src/$newDir
	done
	for aFile in $AddFilesABS
	do
		aa=`readlink -f $aFile`
		bb=${aFile/"$CMSSW_BASE/"/}
		if [ "${aFile}" == "${bb}" ] || [ "${bb:0:1}" == "/" ]; then
			echo "Caution: $aFile is ignored, Out of $CMSSW_BASE"  
			echo "Caution: $aFile is ignored, Out of $CMSSW_BASE" >> $CondorWorkDir/.jobConfigError 
			continue;
		fi
		mkdir -p `dirname $bb`
		ln -s $aa $bb 
		echo "AddedFile $aFile"
	done
	tar zcfh ../input.tgz *
	cd $CondorWorkDir
}

function makeJob() {
	echo "### Make Condor Config "
	cd $FirstDir
	if [ "${ExeFile}" != "" ]; then 
		cp -r `readlink -f $ExeFile` ${CondorWorkDir}/`basename ${ExeFile}`
		bExeFile=`basename $ExeFile`
	fi
	mkdir ${CondorWorkDir}/condorLog 
	totalNFile=`cat $CondorWorkDir/inputfiles.das | wc -l`
	totalNFileT=`expr $totalNFile + $maxFiles - 1`
	nJob=`expr $totalNFileT / $maxFiles`
	echo "NJobs $nJob for $totalNFile / $maxFiles"
#executable = \$ENV(PWD)/${BCondorWorkDir}/condorRun.sh
#initialdir = \$ENV(PWD)/${BCondorWorkDir}
cat << EOF > ${BCondorWorkDir}/job.jdl
executable = \$ENV(PWD)/condorRun.sh
universe = vanilla
output   = condorLog/condorLog_\$(Cluster)_\$(Process).log
error    = condorLog/condorLog_\$(Cluster)_\$(Process).log
log      = /dev/null
use_x509userproxy = True
should_transfer_files = yes
initialdir = \$ENV(PWD)
transfer_input_files = input.tgz, inputfiles.das, ${bExeFile}
when_to_transfer_output = ON_EXIT
transfer_output_files = condorOut, cmsRunLog 
environment = CONDOR_ID=\$(Cluster)_\$(Process)
arguments = 0 ${maxFiles} ${XrdOutPATH} ${ReturnOutput}
queue $nJob 
EOF
rm -rf ${CondorWorkDir}/input
}

if [ "$dataInList" == "" ]; then
	makeList
else 
	echo "### Copy List searching  $dataInList"
	cp $dataInList $CondorWorkDir/inputfiles.das
	cp $CondorWorkDir/inputfiles.das $CondorWorkDir/.inputfiles.das
	echo "`cat $CondorWorkDir/inputfiles.das | wc -l` files "
	head -n 1 $CondorWorkDir/inputfiles.das
	if [ "`cat $CondorWorkDir/inputfiles.das | wc -l`" == "0" ]; then echo "Not Found Files in $dataset" >> $CondorWorkDir/.jobConfigError ; fi
fi

makeCMSSW
makeCode
makeTAR
makeJob


cd $FirstDir
cd `dirname $CondorWorkDir`
tar zchf .${BCondorWorkDir}.tgz ${BCondorWorkDir}
cd $FirstDir


mv .${BCondorWorkDir}.tgz ${CondorWorkDir}/

if [ -f $CondorWorkDir/.jobConfigError ]; then
	echo ""
	echo -e "${Red} ### Condor Setup Error "
	cat $CondorWorkDir/.jobConfigError
	echo "If Ok, ToSubmit \$> cd ${BCondorWorkDir}; condor_submit job.jdl; cd -"
else
	echo ""
	if [ "$AutoSubmit" == "True" ]; then
		echo -e "${Green}Submitting ${BCondorWorkDir}"
		cd ${BCondorWorkDir}
		condor_submit job.jdl 
		cd -
	else
		echo -e "${Green}ToSubmit \$> cd ${BCondorWorkDir}; condor_submit job.jdl; cd - "
	fi
fi
echo -e "$DColor"


