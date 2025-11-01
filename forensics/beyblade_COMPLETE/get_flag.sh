#!/bin/bash

cat solve.txt | grep -m 1 -oE flag{[0-9a-F]{32}} --color=none
