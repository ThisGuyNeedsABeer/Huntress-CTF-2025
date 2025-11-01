#!/bin/bash

cat solve.txt | grep -m 1 -oE flag{*77ba0.*?} --color=none
