@echo off

set OCT_HOME=C:\Octave\Octave-5.1.0.0\mingw64\bin\
set "PATH=%OCT_HOME%;%PATH%"

set SCRIPTS_DIR=D:\Dropbox\Saad\Tanzania\
start octave-cli-5.1.0.exe --eval "cd(getenv('SCRIPTS_DIR')); engmodel('Input/FRC Data Mtendeli-Tanzania_Sept16.xlsx','Team 2','Output'); quit;