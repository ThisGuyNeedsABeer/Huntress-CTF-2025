#!/bin/bash

cat solve.txt | grep -m1 -oE "flag{.*?}" --color=none 
