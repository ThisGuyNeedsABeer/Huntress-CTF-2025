#!/bin/bash

cat solve.txt | grep -oE flag{.*?} --color=none
