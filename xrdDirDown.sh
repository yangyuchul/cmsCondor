#!/bin/bash

if [ "`which xrd 2> /dev/null`" == "" ]; then echo "NotFound xrd, Set CMSSW"; exit; fi

function WaitJob() {
   numJ=`ps -ef | grep "$1" | wc -l`
   if [ ${numJ} -gt $2 ]; then
      echo "   @ Running $numJ $1 process... wait" 
      sleep 5
      WaitJob $1 $2
   fi
}

GIndex=0
xrdServer=$1
xrdDir=$2
maxCPUs=20
if [ "$2" == "" ]; then echo "usage: $0 xrdSERVER directory"; exit; fi
if [ "$3" != "" ]; then maxCPUs=$3; fi
firstDir=`basename $xrdDir`
baseDir=`dirname $xrdDir`
name=${RANDOM}_${RANDOM}
GListFile=/tmp/xrd_${name}_xrdlist

function listXrd() {
	((GIndex++))
	xrdServer=$1
	xrdDir=$2
	thisTDir=${xrdDir/"$baseDir/"/}
	mkdir -p $thisTDir
	echo "@@@ $xrdServer//${xrdDir} "
	xrd $xrdServer ls $xrdDir > ${GListFile}_${GIndex}
	while read line
	do
		if [ "$line" == "" ]; then continue; fi
		type="`echo $line | awk '{print $1}'`"
		thisName="`echo $line | awk '{print $5}'`"
		if [ "${type:0:1}" == "d" ]; then
			listXrd $xrdServer $thisName
		else 
			echo "   @ xrdcp root://${xrdServer}//${thisName} ${thisTDir}/`basename ${thisName}`"
			xrdcp -np root://${xrdServer}//${thisName} ${thisTDir}/`basename ${thisName}` 
		fi
	done < ${GListFile}_${GIndex}
	rm -rf ${GListFile}_${GIndex}  
}

listXrd $xrdServer $xrdDir
#rm -rf /tmp/xrd_${name}_xrdlist*

