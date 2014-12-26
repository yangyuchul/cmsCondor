#!/bin/bash

doDetail=False
logs=""

function ThisCheck() {
dir=$1
cd $dir

if [ ! -d condorLog ]; then
	echo "Not Found CondorDir"
	echo "Usage $0 CondorDir"
	exit
fi

rm -rf .status
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
		echo "@@@ Run ${clusterId}.${condorId} [ R: $nRun I: $nIdle D: $nDone / T: $logFilesN ]" >> .status
		tail -n 1 .status
		if [ "$doDetail" == "True" ]; then
			condor_tail -maxbytes 102400 ${clusterId}.${condorId} >> .status
			tail -n 1 .status
			echo "" >> .status
			tail -n1 .status
		fi
	elif [ "${isIdle}" == "1" ]; then
		((nIdle++))
		echo "@@@ Idle ${clusterId}.${condorId} [ R: $nRun I: $nIdle D: $nDone / T: $logFilesN ]" >> .status
		tail -n 1 .status
	else
		((nDone++))
		echo "@@@ Done ${clusterId}.${condorId} [ R: $nRun I: $nIdle D: $nDone / T: $logFilesN ]" >> .status
		tail -n 1 .status
		if [ "$doDetail" == "True" ]; then
			grep "SummaryRunInformation" $logFile >> .status
			echo "" >> .status
			tail -n 2 .status
		fi
	fi
done
echo "" >> .status
tail -n 1 .status
echo "### Summary Run: $nRun   Idle: $nIdle   Done: $nDone  /  Total $logFilesN" >> .status
tail -n 1 .status
logs="$dir/.status $logs"
}


dirs=""
for arg in $@
do
	if [ "$arg" == "-detail" ]; then doDetail=True; continue; fi
	if [ -d $arg ]; then
		dirs="${dirs} ${arg}"
	else
		"NotFound $arg directory"
	fi
done

firstDir=$PWD
for dir in $dirs ; do cd $firstDir; ThisCheck $dir; done
echo ""
for log in $logs; do echo "See $log"; done


