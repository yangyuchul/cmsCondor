#!/bin/bash

if [ "$1" != "" ]; then
	dir=$1
else
	dir="./"
fi
logFiles=`ls -1 $dir/condorLog/condorLog_*.log`
nlogFiles=`ls -1 $dir/condorLog/condorLog_*.log | wc -l`

nOK=0
nFail=0
nTotal=0
failedLog="failed_${RANDOM}_${RANDOM}"
failed_inputfiles="failed_inputfiles.das"


rm -rf $failedLog $failed_inputfiles
for logFile in $logFiles
do
	((nTotal++))

	nDAS=`grep "SummaryRunInformation ThisSumNEventsInDAS=" $logFile | awk '{print $3}'`
	nTot=`grep "SummaryRunInformation ThisEventSummary="    $logFile | awk '{print $7}'`
	nFil=`grep "SummaryRunInformation ThisEventSummary="    $logFile | awk '{print $10}'`
	nCut=`grep "SummaryRunInformation ThisEventSummary="    $logFile | awk '{print $13}'`

	if [ "$nDAS" == "$nTot" ] ; then
		((nOK++))
		rootFile=`grep "SummaryRunInformation ThisOutFileName=" $logFile | awk '{print $3}'`
		rootFile=`basename $rootFile`
		logFile=`basename $logFile`
		cmsRunLog=${logFile/condorLog/cmsRunLog}
		nOkFiles=`ls -1 ${dir}/cmsRunLog/${cmsRunLog} ${dir}/condorLog/${logFile}  ${dir}/condorOut/${rootFile} | wc -l`
		echo "ThisOk IntFail $nFail + IntOk $nOK / Total $nlogFiles numOutFile $nOkFiles $logFile $rootFile $cmsRunLog" 
		if [ "$2" == "-move" ]; then
			if [ "$nOkFiles" == "3" ] ; then
				if [ ! -d ${dir}/result/cmsRunLog ]; then mkdir -p ${dir}/result/cmsRunLog; fi
				if [ ! -d ${dir}/result/condorLog ]; then mkdir -p ${dir}/result/condorLog; fi
				if [ ! -d ${dir}/result/condorOut ]; then mkdir -p ${dir}/result/condorOut; fi
				mv ${dir}/cmsRunLog/${cmsRunLog} ${dir}/result/cmsRunLog/
				mv ${dir}/${dir}/condorLog/${logFile} ${dir}/result/condorLog
				mv ${dir}/condorOut/${rootFile} ${dir}/result/condorOut 
			else 
				echo "	@ condorOut Files not 3 ${dir}/cmsRunLog/${cmsRunLog} ${dir}/condorLog/${logFile}  ${dir}/condorOut/${rootFile}" >> $failedLog
			fi
		fi
	else
		((nFail++))
		echo "ThisFail $nFail + $nOK / $nTotal $logFile $rootFile" 
		echo "This Fail $nFail + $nOK / $nTotal $logFile $rootFile" >> ${failedLog}
		echo "   @ nDAS $nDAS nTotal $nTot nt $nFil cut $nCut" >> ${failedLog}
		for file in `grep "SummaryRunInformation ThisInputRootFiles=" ${logFile} | awk '{$1 = ""; $2 = ""; print}'`
		do
			bName=`basename $file`
			grep "$bName" $dir/.inputfiles.das >> $failed_inputfiles
		done
	fi
done

if [ -f $failedLog ]; then
	echo "### Start Failed "
	cat $failedLog
	echo "### End Failed"
fi


