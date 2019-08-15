@echo off

set OCT_HOME=C:\Octave\Octave-5.1.0.0\mingw64\bin\
set "PATH=%OCT_HOME%;%PATH%"

set SCRIPTS_DIR=D:\Dropbox\Engineering Optimization Model\
start octave-cli-5.1.0.exe --eval "cd(getenv('SCRIPTS_DIR')); engmodel('Input/SWOT_TS and HH - latest version - False - 2019-07-30-01-27-31.xlsx','SWOT_TS and HH','Output'); quit;