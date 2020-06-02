#!/bin/bash

octave-cli --eval "test engmodel" | tee log.txt
if grep -q '!!!!! test failed' log.txt; then
  echo "TESTS FAILED, EXITING WITH STATUS CODE 1"
  exit 1
fi

