#!/bin/bash
make clean
find . -type d -name .deps -exec rm -rf {} \;
find . -type f -name "*.o" -exec rm {} \;
find . -type f -name "*.lo" -exec rm {} \;