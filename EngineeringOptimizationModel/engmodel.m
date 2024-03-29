function [output_filenames,reco]=engmodel(filein,output,scenario,inputtime,varargin)
%Engineering Optimization Model for SWOT
%Saad Ali

%Version 1.7
%-moved scenario and optimization time to function arguments

%Version 1.6
%-limited results.xlsx outputs to 3 decimal places
%-created new histogram output to show elapsed time for each samples
%
%Version 1.5
%-changed to read decay scenario and input optimization time from filename
%-removed full dataset name from results output table
%-modified contour plot to show markers for maximum and minimum C0 based on input time instead of 12h
%-adjusted axis range on empirical backcheck graph
%-modified font sizes in empirical backcheck graph for better fit
%-modified backcheck graph to only show selected decay scenario
%-added command line output for EO recommendation
%
%Version 1.4
%-corrected how missing data is handled when reading xlsx files
%-corrected issue causing data to be skipped when reading csv files
%-changed graphical details of backcheck graph
%-added output for number of points used in backcheck graphs to graph title
%-added output for number of points used in optimization to spreadsheet output
%-corrected how missing data is handled when reading csv files
%-added functionality for variable number of inputs
%-added functionality for input of time to be optimized for
%-added functionality to read 'date' format time rather than 'string' format in xls and csv
%
%Version 1.3
%-modified to allow .csv input
%-removed required 'sheet' input
%
%Version 1.2
%-added in function to look for 'ts_frc' if 'ts_frc1' not available in input file
%
%Version 1.1
%-looks for columns containing 'ts_datetime', 'ts_frc1', 'hh_datetime',
% and 'hh_frc1' instead of fixed column number
%-relabeled graph filenames and titles with version and input filenames
%-changed target FRC at household from 0.2 to 0.3 mg/L
%-added in success rate on empirical backcheck graph

clc;
format long;
pkg load statistics;
pkg load io;
version='1.7';

if nargin==0
    sprintf('Require input file path')
    return;
end
if nargin<2
  output='Output';
end

[inputFileDir, inputFileName, inputFileExt] = fileparts(filein);
% Specify dictionary containing all output file names to test for their existence
output_filenames = struct();
output_filenames.results = sprintf('%s/%s_Results.xlsx',output,inputFileName);
output_filenames.backcheck = sprintf('%s/%s_Backcheck.png',output,inputFileName);
output_filenames.contour = sprintf('%s/%s_Contour.png',output,inputFileName);
output_filenames.histo = sprintf('%s/%s_Histogram.png',output,inputFileName);
output_filenames.skipped = sprintf('%s/%s_SkippedRows.csv',output,inputFileName);
output_filenames.ruleset = sprintf('%s/%s_Ruleset.csv',output,inputFileName);
output_filenames.json = sprintf('%s/%s_Data.json',output,inputFileName);

% Specify column names expected in CSV file in a struct
cols = struct();
cols.ts_datetime = 'ts_datetime';
cols.ts_frc = 'ts_frc';
cols.hh_datetime = 'hh_datetime';
cols.hh_frc = 'hh_frc';
cols.ts_cond = 'ts_cond';
cols.ts_wattemp = 'ts_wattemp';

% Declare struct variable to keep output for JSON
jsonobject = struct();


%parse time and decay scenario
if ~strcmp(class(inputtime), "double")
  inputtime=str2num(inputtime);
endif

if strcmp(inputFileExt,'.xlsx')
  [numdata strdata alldata]=xlsread(filein);
  header=strdata(1,:);
  alldata(cellfun(@isempty,alldata))=-1;
else
  fid=fopen(filein,'rt');
  temp=csvread(filein);
  headerline = fgetl(fid);
  header=strsplit(headerline,',');
end
  
timecol1=find(strcmp(header,cols.ts_datetime));
frccol1=find(strcmp(header,'ts_frc1'));
if isempty(frccol1)
  frccol1=find(strcmp(header,cols.ts_frc));
end
timecol2=find(strcmp(header,cols.hh_datetime));
frccol2=find(strcmp(header,'hh_frc1'));
if isempty(frccol2)
  frccol2=find(strcmp(header,cols.hh_frc));
end
condcol=find(strcmp(header,cols.ts_cond));
tempcol=find(strcmp(header,cols.ts_wattemp));

% excel file
if strcmp(inputFileExt,'.xlsx')
  fprintf(2, "Warning: .xlsx formats must have one datetime format");
  fprintf(2, "Warning: Discontinued support for xlsx, please re-run with csv for more accurate results");
  tstimedata=strdata(2:end,timecol1);
  tsfrcdata=[alldata{2:end,frccol1}]';
  hhtimedata=strdata(2:end,timecol2);
  hhfrcdata=[alldata{2:end,frccol2}]';
  if isempty(tstimedata)
    tstimedata=[alldata{2:end,timecol1}]';
  end
  if isempty(hhtimedata)
    hhtimedata=[alldata{2:end,timecol2}]';
  end
% csv file
else
  fmt = [repmat('%*s',1,timecol1-1) '%s' repmat('%*s',1,frccol1-timecol1-1) '%f' repmat('%*s',1,timecol2-frccol1-1) '%s' repmat('%*s',1,frccol2-timecol2-1) '%f%[^\n]'];

  alldata = parse_csv(filein);
  tstimedata=alldata{timecol1};
  hhtimedata=alldata{timecol2};
  tsfrcdata=alldata{frccol1};
  hhfrcdata=alldata{frccol2};
  conddata=alldata{condcol};
  tempdata=alldata{tempcol};
  cell2doubles = @(x) str2num(x);
  tsfrcdata=cellfun(cell2doubles,tsfrcdata)';
  hhfrcdata=cellfun(cell2doubles,hhfrcdata)';
  

  [se1tfull,~] = parse_dates(tstimedata);
  [se2tfull,~] = parse_dates(hhtimedata);
  
  fclose(fid);
end
  


se1f=tsfrcdata;
se2f=hhfrcdata;
se1tfull=se1tfull';
se2tfull=se2tfull';

se1t=(se1tfull-se1tfull);
se2t=(se2tfull-se1tfull);
se2t(se2t<0)=se2t(se2t<0)+24;

lowtime=inputtime-3;
hightime=inputtime+3;
bad2=se2f<=0 | se1f <=0 | isnan(se2f) | se1tfull<0 | se2tfull<0 | se2t<lowtime | se2t>hightime; %only look at data around 12h
se1fsave=se1f(bad2==0);
se2fsave=se2f(bad2==0);
se2tsave=se2t(bad2==0);

f01=se1f;
f02=se1f;

%builds a vector of elements that need to be removed from each measurement time
%checks if any concentration is greater than FRC1 by 0.05 and 5%
%also checks if concentrations or times are negative (ie. blank) to remove those elements

% function to concatenate a ruleset with a new rule, returns a new rule set with the added rule
addrule = @(rules, description, column, matches) ([rules, struct('description', description, 'column', column, 'matches', matches)]);

% initialize empty rule set
rules = [];

% add rules to the rule set
rules = addrule(rules, 'Household FRC is greater than tapstand by 0.03', strjoin({cols.ts_frc, cols.hh_frc}, ','), se2f>se1f+0.03);
rules = addrule(rules, 'Household FRC is less than 0', cols.hh_frc, se2f<0);
rules = addrule(rules, 'Invalid tapstand date/time', cols.ts_datetime, se1tfull<0);
rules = addrule(rules, 'Invalid household date/time', cols.hh_datetime, se2tfull<0);
rules = addrule(rules, 'Difference between tapstand and household times is over a year', strjoin({cols.ts_datetime, cols.hh_datetime}, ','), se2t>8760);
rules = addrule(rules, 'Tapstand time is erroneously after household time difference', strjoin({cols.ts_datetime, cols.hh_datetime}, ','), se2t<=0 | isnan(se2t));
rules = addrule(rules, 'Invalid tapstand FRC', cols.ts_frc, isnan(se1f));
rules = addrule(rules, 'Invalid household FRC', cols.hh_frc, isnan(se2f));

bad=0;
fp_ruleset = fopen(output_filenames.ruleset, 'w');
fprintf(fp_ruleset, 'Description,Count\n');
for i = 1:length(rules)
  rule = rules(i);
  bad = bad | rule.matches;
  fprintf(fp_ruleset,'%s,%d\n', rule.description, sum(rule.matches));
endfor
fclose(fp_ruleset);

% get indices of rows that are erroneous
skipped_rows_indices = find(bad==1);
skipped_rows = {};

if strcmp(inputFileExt, '.csv')
  for i = 1:length(skipped_rows_indices)
    idx = skipped_rows_indices(i);
    time1 = tstimedata{idx};
    time2 = hhtimedata{idx};
    frc1 = tsfrcdata(idx);
    frc2 = hhfrcdata(idx);
    cond = conddata{idx};
    temp = tempdata{idx};
    reason = '';
    for j = 1:length(rules)
      if (rules(j).matches(idx))
        reason = rules(j).column;
        break;
      endif
    endfor
    skipped_rows(end+1,:) = {time1, frc1, time2, frc2, cond, temp, reason};
  endfor

  headers = {cols.ts_datetime, cols.ts_frc, cols.hh_datetime, cols.hh_frc, cols.ts_cond, cols.ts_wattemp, "reason"};
  cell2csv(output_filenames.skipped, [headers;skipped_rows]);
end

%remove all previously determined bad elements from each pair of vectors
se1t=se1t(bad==0);
se1f=se1f(bad==0);
se2t=se2t(bad==0);
se2f=se2f(bad==0);
f01=f01(bad==0);
f02=f02(bad==0);

%number of samples in each vector
n1=length(se1f);
n2=length(se2f);
% [n1 n2 n3 n4 n5]
n2only=sum([n1]);

t=[se1t;se2t];
f=[se1f;se2f];
w=ones(length(t),1);
f0=[f01;f02];
f(f<0)=0;
f0_full=f0;
f_full=f;
t_full=t;

%randomly reserve 10% of data for testing
testset=randsample(length(t),round(0.1*length(t)));
t_test=t(testset);
f_test=f(testset);
w_test=w(testset);
f0_test=f0(testset);
t(testset)=[];
f(testset)=[];
w(testset)=[];
f0(testset)=[];

%randomize initial guess 0<k<0.6, 0<n<2
k=rand(5,2);
k(:,1)=k(:,1)*0.6;
k(:,2)=k(:,2)*2;

%%
%standard approach model 1

for i=1:5
  [a_1(i,1:2) sse_1(i)]=fminsearch(@fun,k(i,:),'',t,f,f0,w);
  fpred=(f0.^(1-a_1(i,2))+(a_1(i,2)-1)*a_1(i,1)*t).^(1/(1-a_1(i,2)));
  fpred(fpred<0)=0;
  fpred(f0.^(1-a_1(i,2))<-(a_1(i,2)-1)*a_1(i,1)*t)=0;
  sse_1(i)=sum((f-fpred).^2);
  % fpred=(f0.^(1-a(2))+(a(2)-1)*a(1)*t).^(1-a(2));
  sst_1(i)=sum((f-mean(f)).^2);
  R2_1(i)=1-sse_1(i)/sst_1(i);
  
  sse_FRC2_1(i)=sum((f(t>=4)-fpred(t>=4)).^2);
  sst_FRC2_1(i)=sum((f(t>=4)-mean(f(t>=4))).^2);
  R2_FRC2_1(i)=1-sse_FRC2_1(i)/sst_FRC2_1(i);
  
  ## e1=fpred./f;
  ## e2=f./fpred;
  ## ee=[e1(e1>e2)-1;e2(e2>=e1)-1];
  ## en=normpdf(ee,0.5,0.15);
  ## SSR_1(i)=sum(en)/length(en);
  
  ## e1=fpred(t>=4)./f(t>=4);
  ## e2=f(t>=4)./fpred(t>=4);
  ## ee=[e1(e1>e2)-1;e2(e2>=e1)-1];
  ## en=normpdf(ee,0.5,0.15);
  ## SSR_FRC2_1(i)=sum(en)/length(en);
  
  res=f-fpred;
  sumres_1(i)=sum(res);
  sumres_FRC2_1(i)=sum(res(t>=4));
  resmod(i,:)=res.^2;

  C6_1(i)=(0.3^(1-a_1(i,2))-(a_1(i,2)-1)*a_1(i,1)*6)^(1/(1-a_1(i,2)));
  C9_1(i)=(0.3^(1-a_1(i,2))-(a_1(i,2)-1)*a_1(i,1)*9)^(1/(1-a_1(i,2)));
  C12_1(i)=(0.3^(1-a_1(i,2))-(a_1(i,2)-1)*a_1(i,1)*12)^(1/(1-a_1(i,2)));
  C15_1(i)=(0.3^(1-a_1(i,2))-(a_1(i,2)-1)*a_1(i,1)*15)^(1/(1-a_1(i,2)));
  C18_1(i)=(0.3^(1-a_1(i,2))-(a_1(i,2)-1)*a_1(i,1)*18)^(1/(1-a_1(i,2)));
  C21_1(i)=(0.3^(1-a_1(i,2))-(a_1(i,2)-1)*a_1(i,1)*21)^(1/(1-a_1(i,2)));
  C24_1(i)=(0.3^(1-a_1(i,2))-(a_1(i,2)-1)*a_1(i,1)*24)^(1/(1-a_1(i,2)));
  Cin_1(i)=(0.3^(1-a_1(i,2))-(a_1(i,2)-1)*a_1(i,1)*inputtime)^(1/(1-a_1(i,2)));
  
  %test set
  fpred_test=(f0_test.^(1-a_1(i,2))+(a_1(i,2)-1)*a_1(i,1)*t_test).^(1/(1-a_1(i,2)));
  fpred_test(fpred_test<0)=0;
  fpred_test(f0_test.^(1-a_1(i,2))<-(a_1(i,2)-1)*a_1(i,1)*t_test)=0;
  sse_1_test(i)=sum((f_test-fpred_test).^2);
  sst_1_test(i)=sum((f_test-mean(f_test)).^2);
  R2_1_test(i)=1-sse_1_test(i)/sst_1_test(i);
  
  sse_FRC2_1_test(i)=sum((f_test(t_test>=4)-fpred_test(t_test>=4)).^2);
  sst_FRC2_1_test(i)=sum((f_test(t_test>=4)-mean(f_test(t_test>=4))).^2);
  R2_FRC2_1_test(i)=1-sse_FRC2_1_test(i)/sst_FRC2_1_test(i);
  
  ## e1_test=fpred_test./f_test;
  ## e2_test=f_test./fpred_test;
  ## ee_test=[e1_test(e1_test>e2_test)-1;e2_test(e2_test>=e1_test)-1];
  ## en_test=normpdf(ee_test,0.5,0.15);
  ## SSR_1_test(i)=sum(en_test)/length(en_test);
  
  ## e1_test=fpred_test(t_test>=4)./f_test(t_test>=4);
  ## e2_test=f_test(t_test>=4)./fpred_test(t_test>=4);
  ## ee_test=[e1_test(e1_test>e2_test)-1;e2_test(e2_test>=e1_test)-1];
  ## en_test=normpdf(ee_test,0.5,0.15);
  ## SSR_FRC2_1_test(i)=sum(en_test)/length(en_test);
  
  res_test=f_test-fpred_test;
  sumres_1_test(i)=sum(res_test);
  sumres_FRC2_1_test(i)=sum(res_test(t_test>=4));
  resmod_test(i,:)=res_test.^2;

  C6_1_test(i)=(0.3^(1-a_1(i,2))-(a_1(i,2)-1)*a_1(i,1)*6)^(1/(1-a_1(i,2)));
  C9_1_test(i)=(0.3^(1-a_1(i,2))-(a_1(i,2)-1)*a_1(i,1)*9)^(1/(1-a_1(i,2)));
  C12_1_test(i)=(0.3^(1-a_1(i,2))-(a_1(i,2)-1)*a_1(i,1)*12)^(1/(1-a_1(i,2)));
  C15_1_test(i)=(0.3^(1-a_1(i,2))-(a_1(i,2)-1)*a_1(i,1)*15)^(1/(1-a_1(i,2)));
  C18_1_test(i)=(0.3^(1-a_1(i,2))-(a_1(i,2)-1)*a_1(i,1)*18)^(1/(1-a_1(i,2)));
  C21_1_test(i)=(0.3^(1-a_1(i,2))-(a_1(i,2)-1)*a_1(i,1)*21)^(1/(1-a_1(i,2)));
  C24_1_test(i)=(0.3^(1-a_1(i,2))-(a_1(i,2)-1)*a_1(i,1)*24)^(1/(1-a_1(i,2)));
  Cin_1_test(i)=(0.3^(1-a_1(i,2))-(a_1(i,2)-1)*a_1(i,1)*inputtime)^(1/(1-a_1(i,2)));
end

  kmax=3*round(100*a_1(i,1))/100;
  fpred=[];
  for ii=1:301
    for j=1:301
      a1=(ii-1)*0.01;    %0<n<3
      a2=(j-1)*kmax/300;   %0<k<kmax
      if a1==1
        fpred=f0_full.*exp(-a2*t_full);
        C6(ii,j)=0.3/exp(-a2*6);
        C9(ii,j)=0.3/exp(-a2*9);
        C12(ii,j)=0.3/exp(-a2*12);
        C15(ii,j)=0.3/exp(-a2*15);
        C18(ii,j)=0.3/exp(-a2*18);
        C21(ii,j)=0.3/exp(-a2*21);
        C24(ii,j)=0.3/exp(-a2*24);
        Cin(ii,j)=0.3/exp(-a2*inputtime);
      else
        fpred=(f0_full.^(1-a1)+(a1-1)*a2*t_full).^(1/(1-a1));
        C6(ii,j)=(0.3^(1-a1)-(a1-1)*a2*6)^(1/(1-a1));
        C9(ii,j)=(0.3^(1-a1)-(a1-1)*a2*9)^(1/(1-a1));
        C12(ii,j)=(0.3^(1-a1)-(a1-1)*a2*12)^(1/(1-a1));
        C15(ii,j)=(0.3^(1-a1)-(a1-1)*a2*15)^(1/(1-a1));
        C18(ii,j)=(0.3^(1-a1)-(a1-1)*a2*18)^(1/(1-a1));
        C21(ii,j)=(0.3^(1-a1)-(a1-1)*a2*21)^(1/(1-a1));
        C24(ii,j)=(0.3^(1-a1)-(a1-1)*a2*24)^(1/(1-a1));
        Cin(ii,j)=(0.3^(1-a1)-(a1-1)*a2*inputtime)^(1/(1-a1));
      end
      fpred(f0_full.^(1-a1)<-(a1-1)*a2*t_full)=0;
      sse1(ii,j)=sum((f_full-fpred).^2);
    end
  end
  
 minsse=min(min(sse1));
 C=C24(sse1<minsse*1.05);
 minC24(1:5)=min(C);
 maxC24(1:5)=max(C);
 C6_good=C6(sse1<minsse*1.05);
 minC6(1:5)=min(C6_good);
 maxC6(1:5)=max(C6_good);
 C9_good=C9(sse1<minsse*1.05);
 minC9(1:5)=min(C9_good);
 maxC9(1:5)=max(C9_good);
 C12_good=C12(sse1<minsse*1.05);
 minC12(1:5)=min(C12_good);
 maxC12(1:5)=max(C12_good);
 C15_good=C15(sse1<minsse*1.05);
 minC15(1:5)=min(C15_good);
 maxC15(1:5)=max(C15_good);
 C18_good=C18(sse1<minsse*1.05);
 minC18(1:5)=min(C18_good);
 maxC18(1:5)=max(C18_good);
 C21_good=C21(sse1<minsse*1.05);
 minC21(1:5)=min(C21_good);
 maxC21(1:5)=max(C21_good);
 Cin_good=Cin(sse1<minsse*1.05);
 minCin(1:5)=min(Cin_good);
 maxCin(1:5)=max(Cin_good);
 
 minpoint=find(C12==min(C12_good));
 minK=floor(minpoint/301)*kmax/300;
 minN=mod(minpoint-1,301)*0.01;
 maxpoint=find(C12==max(C12_good));
 maxK=floor(maxpoint/301)*kmax/300;
 maxN=mod(maxpoint-1,301)*0.01;
 optpoint=find(sse1==minsse);
 optK=floor(optpoint/301)*kmax/300;
 optN=mod(optpoint-1,301)*0.01;
  
 %for histogram
## histoy=zeros(24,1);
 highs = ceil(se2t);
 histoy = zeros(max(highs),1);
 for i=1:length(se2t)
   histoy(highs(i))=histoy(highs(i),1)+1;
 end
 
 bar([1:length(histoy)],histoy)
 hold on;
 xtick=[1:length(histoy)];
 
 xticklabel = {};
 for i = 1:length(histoy)
##  xticklabel{i} = sprintf('%d-%d',i-1,i);
  xticklabel{i} = sprintf('%d',i-1);
 end
 set(gca,'xtick',xtick,'xticklabel',xticklabel)
 h=get(gca,'xlabel');
 xlabelposition=get(h,'position');
 yposition=xlabelposition(2)+1;
 yposition=repmat(yposition,length(xtick),1);
 xlh=xlabel('Elapsed Time (hr)');
 ylabel('Number of samples');
 title(sprintf('SWOT Engineering Optimization Model - Histogram of Elapsed Sample Times\nDataset: %s\nCode Version: %s',inputFileName,version),'FontSize',10);
 hold off;
 saveas (gcf,output_filenames.histo);
 
 %for contour
 set(0,'DefaultTextInterpreter','none');
 h=figure;
 contour(0:kmax/300:kmax,0:0.01:3,sse1,minsse*[1.05:0.05:2]);
 hold on;
 xlabel('Decay Rate, k (hr-1)');
 ylabel('Rate Order, n (dimensionless)');
 p(1)=plot(optK,optN,'kx');
 p(2)=plot(minK,minN,'bx');
 p(3)=plot(maxK,maxN,'rx');
 lgd1=legend([p(1) p(2) p(3)],'Optimum Solution',sprintf('Minimum Prediction for C0(t=%dh)',inputtime),sprintf('Maximum Prediction for C0(t=%dh)',inputtime),'Location','northwest');
 set(lgd1,'FontSize',8);
 title(sprintf('SWOT Engineering Optimization Model - Sensitivity Contour Plot\nDataset: %s\nCode Version: %s',inputFileName,version),'FontSize',10);
 hold off;
 saveas (gcf,output_filenames.contour);
  
 
    
 ex1=sum(se1fsave>=0.2 & se1fsave<=0.5);
 ex2=sum(se2fsave>=0.2 & se1fsave>=0.2 & se1fsave<=0.5);
 if ex1>0
  expercent=ex2/ex1*100;
 else
  expercent=0;
 end
 pr1=sum(se1fsave>=max(Cin_good)-0.1 & se1fsave<=max(Cin_good)+0.1); %max
 pr2=sum(se2fsave>=0.2 & se1fsave>=max(Cin_good)-0.1 & se1fsave<=max(Cin_good)+0.1);
 if pr1>0
  prpercent=pr2/pr1*100;
 else
  prpercent=0;
 end
 [i ii]=find(max(R2_1));
 pr3=sum(se1fsave>=Cin_1(ii)-0.1 & se1fsave<=Cin_1(ii)+0.1); %opt
 pr4=sum(se2fsave>=0.2 & se1fsave>=Cin_1(ii)-0.1 & se1fsave<=Cin_1(ii)+0.1);
 if pr3>0
  prpercent2=pr4/pr3*100;
 else
  prpercent2=0;
 end
 pr5=sum(se1fsave>=min(Cin_good)-0.1 & se1fsave<=min(Cin_good)+0.1); %max
 pr6=sum(se2fsave>=0.2 & se1fsave>=min(Cin_good)-0.1 & se1fsave<=min(Cin_good)+0.1);
 if pr5>0
  prpercent3=pr6/pr5*100;
 else
  prpercent3=0;
 endif
  
 h=figure;
 hold on
 if isempty(se1fsave)
    text(0.5,0.5,sprintf('ERROR\nNo data available\n in input time range'),'FontSize',48,'horizontalAlignment','center');
 else
  maxFRC=round(max(se1fsave)*1.2*10)/10;
  plot(se1fsave,se2fsave,'o','HandleVisibility','off') 
  xlabel('FRC at Tapstand (mg/L)')
  ylabel('FRC at Household (mg/L)')
  axis([0 maxFRC 0 maxFRC])
  plot([0 maxFRC],[0 maxFRC],'k-','HandleVisibility','off')
  plot([0.2 0.2], [0 maxFRC],'r--')
  plot([0.5 0.5], [0 maxFRC],'r--','HandleVisibility','off')
  if strcmp(scenario,'minDecay')
    plot([min(Cin_good)-0.1 min(Cin_good)-0.1], [0 maxFRC],'b--')
    plot([min(Cin_good)+0.1 min(Cin_good)+0.1], [0 maxFRC],'b--','HandleVisibility','off')
    reco=min(Cin_good);
  elseif strcmp(scenario,'maxDecay')
    plot([max(Cin_good)-0.1 max(Cin_good)-0.1], [0 maxFRC],'b--')
    plot([max(Cin_good)+0.1 max(Cin_good)+0.1], [0 maxFRC],'b--','HandleVisibility','off')
    reco=max(Cin_good);
  else
    plot([Cin_1(ii)-0.1 Cin_1(ii)-0.1], [0 maxFRC],'g--')
    plot([Cin_1(ii)+0.1 Cin_1(ii)+0.1], [0 maxFRC],'g--','HandleVisibility','off')
    reco=Cin_1(ii);
  endif
  
  jsonobject.reco = reco;
 
  plot([0 maxFRC],[0.2 0.2],'k--','HandleVisibility','off')
  text(maxFRC*0.65,0.12,'Household Water Safety Threshold = 0.2 mg/L','FontSize',8)
  title(sprintf('SWOT Engineering Optimization Model - Empirical Back-Check at %d-%dh follow-up (average %2.1fh, n=%d)\nDataset: %s\nCode Version: %s',lowtime,hightime,mean(se2tsave),length(se2tsave),inputFileName,version),'FontSize',10)
  if strcmp(scenario,'minDecay')
    lgd2=legend(sprintf('Existing Guidelines, 0.2 - 0.5 mg/L, %d of %d, %2.1f%% household water safety success rate',ex2,ex1,expercent),sprintf('Proposed Guidelines Minimum, %1.2f - %1.2f mg/L, %d of %d, %2.1f%% household water safety success rate',min(Cin_good)-0.1,min(Cin_good)+0.1,pr6,pr5,prpercent3),'Location', 'NorthWest');
  elseif strcmp(scenario,'maxDecay')
    lgd2=legend(sprintf('Existing Guidelines, 0.2 - 0.5 mg/L, %d of %d, %2.1f%% household water safety success rate',ex2,ex1,expercent),sprintf('Proposed Guidelines Maximum, %1.2f - %1.2f mg/L, %d of %d, %2.1f%% household water safety success rate',max(Cin_good)-0.1,max(Cin_good)+0.1,pr2,pr1,prpercent),'Location', 'NorthWest');
  else
    lgd2=legend(sprintf('Existing Guidelines, 0.2 - 0.5 mg/L, %d of %d, %2.1f%% household water safety success rate',ex2,ex1,expercent),sprintf('Proposed Guidelines Optimum, %1.2f - %1.2f mg/L, %d of %d, %2.1f%% household water safety success rate',Cin_1(ii)-0.1,Cin_1(ii)+0.1,pr4,pr3,prpercent2),'Location', 'NorthWest');
  endif
  set(lgd2,'FontSize',8);
  grid on
 endif

 hold off
 saveas (gcf,output_filenames.backcheck)
 close all
 
 forxls=cell(11,30);
 forxls(1,:)={sprintf('Dataset: %s\nCode Version: %s',inputFileName,version),'Initial guess for k','Initial guess for n','k','n','Number of points used','SSE','R2','Sum of residuals','Minimum C(t=6h)','Optimum C(t=6h)','Maximum C(t=6h)','Minimum C(t=9h)','Optimum C(t=9h)','Maximum C(t=9h)','Minimum C(t=12h)','Optimum C(t=12h)','Maximum C(t=12h)','Minimum C(t=15h)','Optimum C(t=15h)','Maximum C(t=15h)','Minimum C(t=18h)','Optimum C(t=18h)','Maximum C(t=18h)','Minimum C(t=21h)','Optimum C(t=21h)','Maximum C(t=21h)','Minimum C(t=24h)','Optimum C(t=24h)','Maximum C(t=24h)'};
 forxls(2)={'90% Training Set'};
 forxls(7)={'10% Test Set'};
 for i=1:5
  forxls(1+i,2:30)={sprintf('%0.3f',k(i,1)) sprintf('%0.3f',k(i,2)) sprintf('%0.3f',a_1(i,1)) sprintf('%0.3f',a_1(i,2)) length(se1t) sprintf('%0.3f',sse_1(i)) sprintf('%0.3f',R2_1(i)) sprintf('%0.3f',sumres_1(i)) sprintf('%0.3f',minC6(i)) sprintf('%0.3f',C6_1(i)) sprintf('%0.3f',maxC6(i)) sprintf('%0.3f',minC9(i)) sprintf('%0.3f',C9_1(i)) sprintf('%0.3f',maxC9(i)) sprintf('%0.3f',minC12(i)) sprintf('%0.3f',C12_1(i)) sprintf('%0.3f',maxC12(i)) sprintf('%0.3f',minC15(i)) sprintf('%0.3f',C15_1(i)) sprintf('%0.3f',maxC15(i)) sprintf('%0.3f',minC18(i)) sprintf('%0.3f',C18_1(i)) sprintf('%0.3f',maxC18(i)) sprintf('%0.3f',minC21(i)) sprintf('%0.3f',C21_1(i)) sprintf('%0.3f',maxC21(i)) sprintf('%0.3f',minC24(i)) sprintf('%0.3f',C24_1(i)) sprintf('%0.3f',maxC24(i))};
  forxls(6+i,2:30)={sprintf('%0.3f',k(i,1)) sprintf('%0.3f',k(i,2)) sprintf('%0.3f',a_1(i,1)) sprintf('%0.3f',a_1(i,2)) length(se1t) sprintf('%0.3f',sse_1_test(i)) sprintf('%0.3f',R2_1_test(i)) sprintf('%0.3f',sumres_1_test(i)) sprintf('%0.3f',minC6(i)) sprintf('%0.3f',C6_1_test(i)) sprintf('%0.3f',maxC6(i)) sprintf('%0.3f',minC9(i)) sprintf('%0.3f',C9_1_test(i)) sprintf('%0.3f',maxC9(i)) sprintf('%0.3f',minC12(i)) sprintf('%0.3f',C12_1_test(i)) sprintf('%0.3f',maxC12(i)) sprintf('%0.3f',minC15(i)) sprintf('%0.3f',C15_1_test(i)) sprintf('%0.3f',maxC15(i)) sprintf('%0.3f',minC18(i)) sprintf('%0.3f',C18_1_test(i)) sprintf('%0.3f',maxC18(i)) sprintf('%0.3f',minC21(i)) sprintf('%0.3f',C21_1_test(i)) sprintf('%0.3f',maxC21(i)) sprintf('%0.3f',minC24(i)) sprintf('%0.3f',C24_1_test(i)) sprintf('%0.3f',maxC24(i))};
 end

 xlswrite(output_filenames.results,forxls,'A1:AE11');
 jsonfp = fopen(output_filenames.json, "w");
 fputs(jsonfp, object2json(jsonobject));
 fclose(jsonfp);
endfunction

%looking at SSE for all points
function SSE=fun(a,t,f,f0,w)
fpred=(f0.^(1-a(2))+(a(2)-1)*a(1)*t).^(1/(1-a(2)));
SSE=sum(w.*((f-fpred).^2));
endfunction


%!function found = file_found(path)
%!  DIRECTORY_EXISTS = 2;
%!  found = exist(path) == DIRECTORY_EXISTS;
%!endfunction
%!function not_empty = file_not_empty(path)
%!  dinfo = dir(path);
%!  not_empty = dinfo.bytes > 0;
%!endfunction
%!
%!function test_case(input, scenario, inputtime)
%!  EXPECTED_OUTPUT_FILE_COUNT = 7;
%!  outputdirname = tempname();
%!  mkdir(outputdirname);
%!  outputs = engmodel(input, outputdirname, scenario, inputtime);
%!  output_fields = fieldnames(outputs);
%!  assert (length(output_fields) == EXPECTED_OUTPUT_FILE_COUNT)
%!  for i = 1:length(output_fields)
%!    output_fieldname = output_fields{i};
%!    output_filename = getfield(outputs, output_fieldname);
%!    if (file_found(output_filename) == false)
%!      error ("file not found, expected %s", output_filename);
%!    endif
%!    if (file_not_empty(output_filename) == false)
%!      error ("file not empty, expected %s", output_filename);
%!    endif
%!  endfor
%!  confirm_recursive_rmdir(0, "local");
%!  rmdir(outputdirname, "s");
%!endfunction
%!
%!test1
%!  test_case('tests/ds1.csv', 'minDecay', 6)
%!test2
%!  test_case('tests/ds2.csv', 'optimumDecay', 9)
%!test3
%!  test_case('tests/ds3.csv', 'maxDecay', 12)
%!test4
%!  test_case('tests/ds4.csv', 'optimumDecay', 15)
%!test5
%!  test_case('tests/ds5.csv', 'minDecay', 18)
%!
