#!/bin/bash

rm -rf disk/*

gcc main.c -g -o run
./run
