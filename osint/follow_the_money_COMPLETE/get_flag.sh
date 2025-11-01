#!/bin/bash

cat solve.txt | grep -m 1 -oE "flag{.*?}" --color=none
