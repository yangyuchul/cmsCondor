#!/bin/bash

if [ "$CMSSW_BASE" == "" ]; then echo "NotFound CMSSW"; exit; fi

function WaitJob() {
	numJ=`ps -ef | grep "$1" | wc -l`
	if [ ${numJ} -gt 4 ]; then
		echo "   @ Running $numJ $1 process... wait" 
		sleep 10
		WaitJob $1
	fi
}

name=${RANDOM}_${RANDOM}
listFile="/tmp/merge_${name}.list"
rm -rf ${listFile}_*
dir=$1
njobs=$2
outname=$3
strLen=${#njobs}

ntotal=`find $dir -maxdepth 1 -name "*.root" | wc -l`
if [ ${ntotal} == "0" ]; then echo "Not Found EdmFile in $dir"; exit; fi

index=0
for file in `find $dir -maxdepth 1 -name "*.root"`
do
	((index++))
	indexStr=`printf %0${strLen}d $index`
	echo "file:${file}" >> ${listFile}_${indexStr}
	if [ $index -ge $njobs ]; then index=0; fi
done

nstotal=`cat ${listFile}_* | wc -l`
if [ "$ntotal" != "$nstotal" ]; then echo "Diff Total N $ntotal $nstotal"; exit; fi

listFiles=`ls -1 ${listFile}_*`
nlist=`ls -1 ${listFile}_* | wc -l`
index=0
pids=""
rm -rf edmMerge.log
echo "### $ntotal $nstotal $njobs $nlist" 
echo "### $ntotal $nstotal $njobs $nlist" >> edmMerge.log
for list in $listFiles
do
	((index++))
	addName="_n${index}_d${nlist}.root"
	thisOutName=${outname/.root/"${addName}"}
	echo "$index $nlist $list $thisOutName"
	if [ -f ${thisOutName} ]; then echo "$list to ${thisOutName} skip"; continue; fi
	for file in `cat $list`
	do
		echo -n "$file " >> edmMerge.log
	done
	echo "TO ${thisOutName}" >> edmMerge.log
	echo "" >> edmMerge.log

	edmCopyPickMerge inputFiles_load=${list} outputFile=${thisOutName} >& /dev/null &
	pid=$!	
	pids="${pids} ${pid}"
	sleep 1
	WaitJob edmCopyPickMerge
done

echo "Wait Unfinished Jobs $pids"
wait $pids 

echo "Done"
rm -rf ${listFile}*

