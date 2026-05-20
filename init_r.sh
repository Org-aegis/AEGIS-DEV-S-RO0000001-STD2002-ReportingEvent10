#!/bin/bash
# **************************************************************
# Copy .Rprofile and .Renviron to project directory
# **************************************************************
echo "Current Directory: $(pwd)"
echo "*** File list under project directory BEFORE copying ***"
ls -al 2>&1
echo "*** Start copying... ***"
cp /aegis/R/.R* . 2>&1
echo "*** File list under project directory AFTER copying ***"
ls -al 2>&1
