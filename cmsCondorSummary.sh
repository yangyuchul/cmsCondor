#!/bin/bash

logDir=./condorLog
cmsDir=./cmsRunLog
outDir=./condorOut

rm -rf ReadMeSummary
rm -rf ReadMeSummary.war
rm -rf ReadMeSummary.err

echo "## nLog `ls -1 $logDir | wc -l` nCMS `ls -1 $cmsDir | wc -l` nRoot `ls -1 $outDir | wc -l `"
logFiles=`find $logDir -maxdepth 1 -name "condorLog*.log"`
NlogFiles=`find $logDir -maxdepth 1 -name "condorLog*.log" | wc -l`

files=`find $dir -maxdepth 1 -name "condorLog*.log"`
nfiles=`find $dir -maxdepth 1 -name "condorLog*.log" | wc -l`
str="TrigReport Events total ="

idx=0
nOK=0
echo "### Log Check"
for logFile in $logFiles
do
	((NlogFiles--))
	echo -n "$NlogFiles "
	bLogFile=`basename $logFile`
	bCmsFile=${bLogFile/condorLog/cmsRunLog}

	evtLog=`grep "^${str}" $logDir/$bLogFile | tail -n 1`
	evtCms=`grep "^$str" $cmsDir/$bCmsFile`
	
	if [ "$evtLog" != "$evtCms" ]; then
		echo ""
		echo "### Error $logDir/$bLogFile != $cmsDir/$bCmsFile"
		echo "   @ $evtLog       $evtCms"
		echo ""
	else
		echo "$evtCms" >> ReadMeSummary
		((nOK++))
	fi
done
echo ""

nRoot=`ls $outDir/*.root | wc -l`
if [ "$nOK" == "$nRoot" ]; then
	echo "### ROOT Fiie Check"
	~/local/bin/getTreeEntries.exe Events $outDir/*.root 2> /dev/null | tee .rootEvents
else 
	echo "### Error nOK != nROOT $nOK != $nRoot"
fi

nDAS=`cat ../.inputfiles.das | awk '{sum+=$2} END{print sum}'`
nLog=`grep "$str"  ReadMeSummary  | awk '{sum1+=$5; sum2+=$11; sum3+=$8} END{print sum1, "-",sum2,"=", sum3}'`
echo ""
echo "## SummaryEvents $nDAS == $nLog == `tail -n 1 .rootEvents | awk '{print $4}'`" >> ReadMeSummary
tail -n 1 ReadMeSummary
rm -rf .rootEvents





