[![Build Status](https://dev.azure.com/dighr-swot/SWOT/_apis/build/status/dighr.swot-octave-analysis?branchName=master)](https://dev.azure.com/dighr-swot/SWOT/_build/latest?definitionId=3&branchName=master)

# swot-octave-analysis
Repo for SWOT engineering optimization analytics in GNU Octave.

Version 1.6
-limited results.xlsx outputs to 3 decimal places
-created new histogram output to show elapsed time for each samples

Version 1.5
-changed to read decay scenario and input optimization time from filename
-removed full dataset name from results output table
-modified contour plot to show markers for maximum and minimum C0 based on input time instead of 12h
-adjusted axis range on empirical backcheck graph
-modified font sizes in empirical backcheck graph for better fit
-modified backcheck graph to only show selected decay scenario
-added command line output for EO recommendation

Version 1.4
-corrected how missing data is handled when reading xlsx files
-corrected issue causing data to be skipped when reading csv files
-changed graphical details of backcheck graph
-added output for number of points used in backcheck graphs to graph title
-added output for number of points used in optimization to spreadsheet output
-corrected how missing data is handled when reading csv files
-added functionality for variable number of inputs
-added functionality for input of time to be optimized for
-added functionality to read 'date' format time rather than 'string' format in xls and csv

Version 1.3
-modified to allow .csv input
-removed required 'sheet' input

Version 1.2
-added in function to look for 'ts_frc' if 'ts_frc1' not available in input file

Version 1.1
-looks for columns containing 'ts_datetime', 'ts_frc1', 'hh_datetime',
 and 'hh_frc1' instead of fixed column number
-relabeled graph filenames and titles with version and input filenames
-changed target FRC at household from 0.2 to 0.3 mg/L
-added in success rate on empirical backcheck graph
