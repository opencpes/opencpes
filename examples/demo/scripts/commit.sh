#!/bin/bash
KEY="CSA Summit 2019"
BASE="/nfs-postfix/demo"
#
mkdir -p "$BASE/valid"
mkdir -p "$BASE/generic"
mkdir -p "$BASE/process"
mkdir -p "/home/csablockhead/chain"
mkdir -p "/home/csablockhead/keys"
#
SALT=`head -c 64 /dev/urandom | sha512sum --tag - | sed -e 's/.* //g'`
#
CURRENTKEY=`ls -t1 /home/csablockhead/keys | head -n 1`
/home/csablockhead/bc keypair -o /home/csablockhead/keys/`date +%s`.json
NEXTKEY=`ls -t1 /home/csablockhead/keys | head -n 1`
NEXTHASH=`cat /home/csablockhead/keys/$NEXTKEY | grep hash | sed -e 's/.* "\(.*\)".*/\1/g'`
#
PREV=`ls -t1 /home/csablockhead/chain | head -n 1`
#
echo -e "{" > $BASE/block.json
echo -e "  \"keys\": [\"$NEXTHASH\"]," >> $BASE/block.json
echo -e "  \"salt\": \"$SALT\"," >> $BASE/block.json
echo -en "  \"hashes\": [\"$PREV\"" >> $BASE/block.json
#
mv $BASE/valid/* $BASE/process/.
MOVED=$?
if [ $MOVED == 0 ]; then
    echo "Found valid images."
    for FILE in $BASE/process/*; do
        echo -en "$SALT" | xxd -r -p > $BASE/data
        echo -en "$KEY" >> $BASE/data
        HASH=`sha512sum --tag "$FILE" | sed -e 's/.* //g'`
        echo -en "$HASH" >> $BASE/data
        HASH=`sha512sum --tag $BASE/data | sed -e 's/.* //g'`
        echo -en ", \"$HASH\"" >> $BASE/block.json
        rm $BASE/data
        rm "$FILE"
    done
fi
#
mv $BASE/generic/* $BASE/process/.
MOVED=$?
if [ $MOVED == 0 ]; then
    echo "Found other attachments."
    for FILE in $BASE/process/*; do
        echo -en "$SALT" | xxd -r -p > $BASE/data
        HASH=`sha512sum --tag "$FILE" | sed -e 's/.* //g'`
        echo -en "$HASH" >> $BASE/data
        HASH=`sha512sum --tag $BASE/data | sed -e 's/.* //g'`
        echo -en ", \"$HASH\"" >> $BASE/block.json
        rm $BASE/data
        rm "$FILE"
    done
fi
#
echo -e "]," >> $BASE/block.json
NOW=`date +%s`
echo -e "  \"timestamp\": $NOW\n}" >> $BASE/block.json
/home/csablockhead/bc sign -k /home/csablockhead/keys/$CURRENTKEY -i $BASE/block.json -o $BASE/sign.json
rm /home/csablockhead/keys/$CURRENTKEY
#
BLOCKFILE=`sha512sum --tag $BASE/block.json | sed -e 's/.* //g'`
SIGFILE=`sha512sum --tag $BASE/sign.json | sed -e 's/.* //g'`
mv $BASE/block.json /home/csablockhead/chain/$BLOCKFILE
mv $BASE/sign.json /home/csablockhead/chain/$SIGFILE
