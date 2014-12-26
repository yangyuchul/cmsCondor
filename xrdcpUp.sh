#!/bin/bash

function WaitJob() {
   numJ=`ps -ef | grep "$1" | wc -l`
   if [ ${numJ} -gt 3 ]; then
      echo "   @ Running $numJ $1 process... wait" 
      sleep 10
      WaitJob $1
   fi
}

xrdServer=cms-xrdr.sdfarm.kr
xrdDir=""
inDirs=""

for arg in $@
do
	if [ "${arg:0:3}" == "-d=" ]; then 
		xrdDir=`echo $arg | cut -d= -f2`
	else
		inDirs="$arg $inDirs"
	fi
done

if [ "${xrdDir}" == "" ]; then echo "usage: $0 -d=<XRDDir> local_dirs"; exit; fi


xrdDirUp=`dirname $xrdDir`

echo "## Up $xrdDir ######" 
xrd cms-xrdr.sdfarm.kr ls $xrdDirUp 
echo "##"
echo ""

files=`find $inDirs -type f`
nfile=0
for file in $files
do
	((nfile++))
	echo " @ $nfile $file will be copied"
done

idx=0
pids=""
for file in $files
do
	((idx++))
	bName=`basename $file`
	echo "[${idx}/${nfile}] xrdcp $file root://${xrdServer}///${xrdDir}/$bName"
	xrdcp $file root://${xrdServer}://${xrdDir}/$bName &
   pid=$!
   pids="${pids} ${pid}"
   WaitJob xrdcp 
done


