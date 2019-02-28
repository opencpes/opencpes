#!/bin/bash
KEY=""
CUTOFF="1556200800"
#
BASE="/nfs-postfix/demo"
#
if [ `date +%s` \> $CUTOFF ]; then
    echo "Submission deadline has passed."
    exit 1
fi
#
mkdir -p "$BASE/incoming"
mkdir -p "$BASE/parts"
mkdir -p "$BASE/valid"
mkdir -p "$BASE/generic"
#
MAILFILE=`mktemp --tmpdir=$BASE/incoming`
cat - > $MAILFILE
#
PARTDIR=`mktemp -d --tmpdir=$BASE/parts`
mu extract -a --target-dir=$PARTDIR $MAILFILE
#
for IMGFILE in $PARTDIR/*; do
    if zbarimg $IMGFILE | grep "$KEY"; then
        VLDFILE=`mktemp --tmpdir=$BASE/valid`
        mv $IMGFILE $VLDFILE
    else
        VLDFILE=`mktemp --tmpdir=$BASE/generic`
        mv $IMGFILE $VLDFILE
    fi
done
#
rm $MAILFILE
rm -rf $PARTDIR
#
touch $BASE/waiting
