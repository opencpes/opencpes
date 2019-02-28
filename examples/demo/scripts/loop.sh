#!/bin/bash
while true; do
  cd /home/csablockhead
  echo "Checking for attachments to process..."
  rm /nfs-postfix/demo/waiting
  WAITING=$?
  if [ $WAITING == 0 ]; then
    echo -e "\tProcessing attachments..."
    /home/csablockhead/./commit.sh
    sleep 5
    /home/csablockhead/./commit.sh
    rsync -avz /home/csablockhead/chain/* /home/csablockhead/opencpes-blockchain/chain/. 
    HEAD=`ls -t1 /home/csablockhead/chain | head -n 1`
    echo -en "$HEAD" > /home/csablockhead/opencpes-blockchain/chain/top.txt
    cd /home/csablockhead/opencpes-blockchain
    git add chain
    NOW=`date`
    git commit -m "adding new blocks ($NOW)"
    git push origin master
    HEAD=`ls -t1 /home/csablockhead/keys | head -n 1`
    cp /home/csablockhead/keys/$HEAD /home/csablockhead/opencpes-keystore/keys/latest.json
    cd /home/csablockhead/opencpes-keystore
    git add keys
    NOW=`date`
    git commit -m "adding latest key ($NOW)"
    git push origin master
  fi
  sleep 15
done
