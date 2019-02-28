#!/bin/bash
#macos bash script
KEY="CSA Summit 2019"
REPO=/Users/csablockhead/Downloads/demo/opencpes-blockchain
OPENCPE="/Users/csablockhead/Downloads/demo/bin/OpenCPE"
#
if [ $# -eq 0 ]; then
  echo "performing sync"
  cd $REPO
  /usr/bin/git pull
  exit $?
fi
#
HASH=`shasum -a 512 $@`
HASH=`echo -en $HASH | sed -e 's/ .*//g'`
VALUE=$KEY$HASH
TOP=`cat $REPO/chain/top.txt`
$OPENCPE find -v "$VALUE" -f 319da1be59a03c7250f5fc4d8b4e78d3280d2d8605be0ac2f68b3d936301382dd09410b59a25dea58f3fd8c3de98cd21c14f32c79cfb29b9df211f50ecff27ed -t $REPO/chain/$TOP
