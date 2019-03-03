#!/bin/bash
#macos bash script
KEY="CSA Summit 2019"
BASE=`echo $0 | sed -e 's/demo.sh//g'`
REPO="$BASE/opencpes-blockchain"
OPENCPE="$BASE/OpenCPE"
#
if [ $# -eq 0 ]; then
  echo "performing sync"
  cd $REPO
  /usr/bin/git pull
  exit $?
fi
#
if [ "$1" == "report" ]; then
  sleep 3
  open $REPO/status.txt
  exit 0
fi
#
HASH=`shasum -a 512 "$1"`
HASH=`echo -en $HASH | sed -e 's/ .*//g'`
echo -e "hash: $HASH" > $REPO/status.txt
VALUE=$KEY$HASH
if [ $# -eq 1 ]; then
  VALUE=$HASH
fi
TOP=`cat $REPO/chain/top.txt`
$OPENCPE find -v "$VALUE" -f 319da1be59a03c7250f5fc4d8b4e78d3280d2d8605be0ac2f68b3d936301382dd09410b59a25dea58f3fd8c3de98cd21c14f32c79cfb29b9df211f50ecff27ed -t $REPO/chain/$TOP | grep timestamp -B 3 | grep -v record | sed -e 's/processing/block:/g' -e 's/.*timestamp:/block timestamp:/g' -e 's/!//g' >> $REPO/status.txt
RESULT=${PIPESTATUS[0]}
exit $RESULT
