@echo off

set OCT_HOME=C:\Octave\Octave-5.1.0.0\mingw64\bin\
set "PATH=%OCT_HOME%;%PATH%"

set SCRIPTS_DIR=D:\Dropbox\Saad\South Sudan\
start octave-cli-5.1.0.exe --eval "cd(getenv('SCRIPTS_DIR')); engmodel('Input/Data_ChlorineRefugeeCamps_SIAli_May82018.xlsx','South Sudan 2013','Output'); quit;