#!/bin/bash

dir="./"
if [ "${1}" != "" ]; then dir=$1; fi

cd $dir
if [ ! -d condorLog ]; then
	echo "Not Found CondorDir"
	echo "Usage $0 CondorDir"
	exit
fi

logFiles=`ls -1v condorLog/condorLog*.log`
logFilesN=`ls -1v condorLog/condorLog*.log | wc -l`

nRun=0
nIdle=0;
nDone=0
for logFile in $logFiles
do
	blogFile=`basename $logFile`
	blogFile=${blogFile/condorLog_/}
	blogFile=${blogFile/.log/}
	clusterId=`echo $blogFile | cut -d_ -f1`
	condorId=`echo $blogFile | cut -d_ -f2`
	isRunning=`condor_q ${clusterId}.${condorId} | grep " R " | wc -l`
	isIdle=`condor_q ${clusterId}.${condorId} | grep " I " | wc -l`

	if [ "${isRunning}" == "1" ]; then
		((nRun++))
		echo "@@@ Run ${clusterId}.${condorId} [ R: $nRun I: $nIdle D: $nDone / T: $logFilesN ]"
		if [ "$2" == "-detail" ]; then
			condor_tail -maxbytes 102400 ${clusterId}.${condorId} | tail -n 5
			echo ""
		fi
	elif [ "${isIdle}" == "1" ]; then
		((nIdle++))
		echo "@@@ Idle ${clusterId}.${condorId} [ R: $nRun I: $nIdle D: $nDone / T: $logFilesN ]"
	else
		((nDone++))
		grep "@@@ Done ${clusterId}.${condorId} [ R: $nRun I: $nIdle D: $nDone / T: $logFilesN ]"
		if [ "$2" == "-detail" ]; then
			grep "RunSummary" $logFile
			echo ""
		fi
	fi
done
echo ""
echo "### Summary Run: $nRun   Idle: $nIdle   Done: $nDone  /  Total $logFilesN"

