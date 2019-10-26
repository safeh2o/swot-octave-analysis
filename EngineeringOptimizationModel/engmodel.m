function engmodel(csvin,output)
%Engineering Optimization Model for SWOT
%Saad Ali
%
%Version 1.3
%-modified to allow .csv input
%-removed required 'sheet' input
%
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

clc
format long
pkg load statistics
pkg load io
version='1.3';

[inputFileDir, inputFileName, inputFileExt] = fileparts(csvin)

if csvin(end-3:end)=='xlsx'
  [numdata strdata alldata]=xlsread(csvin);
  header=strdata(1,:);
else
  fid=fopen(csvin,'rt');
  temp=csvread(csvin);
  headercell=textscan(fid,'%s',size(temp,2),'Delimiter',',');
  header=cell2mat(headercell);
end
  
timecol1=find(strcmp(header,'ts_datetime'));
frccol1=find(strcmp(header,'ts_frc1'));
if isempty(frccol1)
  frccol1=find(strcmp(header,'ts_frc'));
end
timecol2=find(strcmp(header,'hh_datetime'));
frccol2=find(strcmp(header,'hh_frc1'));
if isempty(frccol2)
  frccol2=find(strcmp(header,'hh_frc'));
end

if csvin(end-3:end)=='xlsx'
  data1=strdata(2:end,timecol1);
  data2=[alldata{2:end,frccol1}]';
  data3=strdata(2:end,timecol2);
  data4=[alldata{2:end,frccol2}]';
else
  fmt = [repmat('%*s',1,timecol1-1) '%s' repmat('%*s',1,frccol1-timecol1-1) '%f' repmat('%*s',1,timecol2-frccol1-1) '%s' repmat('%*s',1,frccol2-timecol2-1) '%f%[^\n]'];
  alldata=textscan(fid,fmt,'Delimiter',',');
  alldata{1}(end)=[];
  alldata{2}(end)=[];
  alldata{3}(end)=[];
  alldata{4}(end)=[];
  if alldata{1}{1}(1:3)=='019'
    alldata{1}{1}=['2' alldata{1}{1}];
  end
  data1=alldata{1};
  data2=alldata{2};
  data3=alldata{3};
  data4=alldata{4};
  fclose(fid);
end
  

for i=1:size(data1,1)
  if ~isempty(data1{i})
    hr=str2num(data1{i}(12:13));
    minute=str2num(data1{i}(15:16));
    second=str2num(data1{i}(18:19));
    se1tfull(i)=hr+minute/60+second/3600; 
  else
    se1tfull(i)=-1;
  end
  
  
  if ~isempty(data3{i})
    hr=str2num(data3{i}(12:13));
    minute=str2num(data3{i}(15:16));
    second=str2num(data3{i}(18:19));
    se2tfull(i)=hr+minute/60+second/3600;
  else
    se2tfull(i)=-1;
  end
  
end
se1f=data2;
se2f=data4;
se1tfull=se1tfull';
se2tfull=se2tfull';

se1t=(se1tfull-se1tfull);
se2t=(se2tfull-se1tfull);
se2t(se2t<0)=se2t(se2t<0)+24;

se1fsave=se1f;
se2fsave=se2f;
bad=se2fsave<=0 | se1fsave <=0 | isnan(se2fsave) | se1tfull<0 | se2tfull<0 | se2t>15; %only look at data around 12h
se1fsave=se1fsave(bad==0);
se2fsave=se2fsave(bad==0);

f01=se1f;
f02=se1f;

%builds a vector of elements that need to be removed from each measurement time
%checks if any concentration is greater than FRC1 by 0.05 and 5%
%also checks if concentrations or times are negative (ie. blank) to remove those elements
bad=se2f>se1f+0.03 | se2f<=0 | se2t<=0 | isnan(se2f) | isnan(se1f);

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
f(f<0.03)=0.03;
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
  fpred(fpred<0.03)=0.03;
  fpred(f0.^(1-a_1(i,2))<-(a_1(i,2)-1)*a_1(i,1)*t)=0.03;
  sse_1(i)=sum((f-fpred).^2);
  % fpred=(f0.^(1-a(2))+(a(2)-1)*a(1)*t).^(1-a(2));
  sst_1(i)=sum((f-mean(f)).^2);
  R2_1(i)=1-sse_1(i)/sst_1(i);
  
  sse_FRC2_1(i)=sum((f(t>=4)-fpred(t>=4)).^2);
  sst_FRC2_1(i)=sum((f(t>=4)-mean(f(t>=4))).^2);
  R2_FRC2_1(i)=1-sse_FRC2_1(i)/sst_FRC2_1(i);
  
  e1=fpred./f;
  e2=f./fpred;
  ee=[e1(e1>e2)-1;e2(e2>=e1)-1];
  en=normpdf(ee,0.5,0.15);
  SSR_1(i)=sum(en)/length(en);
  
  e1=fpred(t>=4)./f(t>=4);
  e2=f(t>=4)./fpred(t>=4);
  ee=[e1(e1>e2)-1;e2(e2>=e1)-1];
  en=normpdf(ee,0.5,0.15);
  SSR_FRC2_1(i)=sum(en)/length(en);
  
  res=f-fpred;
  sumres_1(i)=sum(res);
  sumres_FRC2_1(i)=sum(res(t>=4));
  resmod(i,:)=res.^2;

  C12_1(i)=(0.3^(1-a_1(i,2))-(a_1(i,2)-1)*a_1(i,1)*12)^(1/(1-a_1(i,2)));
  C15_1(i)=(0.3^(1-a_1(i,2))-(a_1(i,2)-1)*a_1(i,1)*15)^(1/(1-a_1(i,2)));
  C24_1(i)=(0.3^(1-a_1(i,2))-(a_1(i,2)-1)*a_1(i,1)*24)^(1/(1-a_1(i,2)));
  
  %test set
  fpred_test=(f0_test.^(1-a_1(i,2))+(a_1(i,2)-1)*a_1(i,1)*t_test).^(1/(1-a_1(i,2)));
  fpred_test(fpred_test<0.03)=0.03;
  fpred_test(f0_test.^(1-a_1(i,2))<-(a_1(i,2)-1)*a_1(i,1)*t_test)=0.03;
  sse_1_test(i)=sum((f_test-fpred_test).^2);
  sst_1_test(i)=sum((f_test-mean(f_test)).^2);
  R2_1_test(i)=1-sse_1_test(i)/sst_1_test(i);
  
  sse_FRC2_1_test(i)=sum((f_test(t_test>=4)-fpred_test(t_test>=4)).^2);
  sst_FRC2_1_test(i)=sum((f_test(t_test>=4)-mean(f_test(t_test>=4))).^2);
  R2_FRC2_1_test(i)=1-sse_FRC2_1_test(i)/sst_FRC2_1_test(i);
  
  e1_test=fpred_test./f_test;
  e2_test=f_test./fpred_test;
  ee_test=[e1_test(e1_test>e2_test)-1;e2_test(e2_test>=e1_test)-1];
  en_test=normpdf(ee_test,0.5,0.15);
  SSR_1_test(i)=sum(en_test)/length(en_test);
  
  e1_test=fpred_test(t_test>=4)./f_test(t_test>=4);
  e2_test=f_test(t_test>=4)./fpred_test(t_test>=4);
  ee_test=[e1_test(e1_test>e2_test)-1;e2_test(e2_test>=e1_test)-1];
  en_test=normpdf(ee_test,0.5,0.15);
  SSR_FRC2_1_test(i)=sum(en_test)/length(en_test);
  
  res_test=f_test-fpred_test;
  sumres_1_test(i)=sum(res_test);
  sumres_FRC2_1_test(i)=sum(res_test(t_test>=4));
  resmod_test(i,:)=res_test.^2;

  C12_1_test(i)=(0.3^(1-a_1(i,2))-(a_1(i,2)-1)*a_1(i,1)*12)^(1/(1-a_1(i,2)));
  C15_1_test(i)=(0.3^(1-a_1(i,2))-(a_1(i,2)-1)*a_1(i,1)*15)^(1/(1-a_1(i,2)));
  C24_1_test(i)=(0.3^(1-a_1(i,2))-(a_1(i,2)-1)*a_1(i,1)*24)^(1/(1-a_1(i,2)));
end

  kmax=3*round(100*a_1(i,1))/100;
  fpred=[];
  for ii=1:301
    for j=1:301
      a1=(ii-1)*0.01;    %0<n<3
      a2=(j-1)*kmax/300;   %0<k<kmax
      if a1==1
        fpred=f0_full.*exp(-a2*t_full);
        C12(ii,j)=0.3/exp(-a2*12);
        C15(ii,j)=0.3/exp(-a2*15);
        C24(ii,j)=0.3/exp(-a2*24);
      else
        fpred=(f0_full.^(1-a1)+(a1-1)*a2*t_full).^(1/(1-a1));
        C12(ii,j)=(0.3^(1-a1)-(a1-1)*a2*12)^(1/(1-a1));
        C15(ii,j)=(0.3^(1-a1)-(a1-1)*a2*15)^(1/(1-a1));
        C24(ii,j)=(0.3^(1-a1)-(a1-1)*a2*24)^(1/(1-a1));
      end
      fpred(fpred<0.03)=0.03;
      fpred(f0_full.^(1-a1)<-(a1-1)*a2*t_full)=0.03;
      sse1(ii,j)=sum((f_full-fpred).^2);
    end
  end
  
 minsse=min(min(sse1));
 C=C24(sse1<minsse*1.05);
 minC24(1:5)=min(C);
 maxC24(1:5)=max(C);
 C2=C12(sse1<minsse*1.05);
 minC12(1:5)=min(C2);
 maxC12(1:5)=max(C2);
 C3=C15(sse1<minsse*1.05);
 minC15(1:5)=min(C3);
 maxC15(1:5)=max(C3);
 minpoint=find(C12==min(C2));
 minK=floor(minpoint/301)*kmax/300;
 minN=mod(minpoint-1,301)*0.01;
 maxpoint=find(C12==max(C2));
 maxK=floor(maxpoint/301)*kmax/300;
 maxN=mod(maxpoint-1,301)*0.01;
 optpoint=find(sse1==minsse);
 optK=floor(optpoint/301)*kmax/300;
 optN=mod(optpoint-1,301)*0.01;
  
 set(0,'DefaultTextInterpreter','none')
 h=figure;
 contour(0:kmax/300:kmax,0:0.01:3,sse1,minsse*[1.05:0.05:2])
 hold on
 xlabel('Decay Rate, k (hr-1)')
 ylabel('Rate Order, n (dimensionless)')
 p(1)=plot(optK,optN,'kx');
 p(2)=plot(minK,minN,'bx');
 p(3)=plot(maxK,maxN,'rx');
 legend([p(1) p(2) p(3)],'Optimum Solution','Minimum Prediction for C0(t=12h)','Maximum Prediction for C0(t=12h)','Location','northwest')
 title(sprintf('SWOT Engineering Optimization Model - Sensitivity Contour Plot\nDataset: %s\nCode Version: %s',inputFileName,version))
 hold off
 saveas (gcf,sprintf('%s/%s_Contour.png',output,inputFileName))
  
 ex1=sum(se1fsave>=0.2 & se1fsave<=0.5);
 ex2=sum(se2fsave>=0.2 & se1fsave>=0.2 & se1fsave<=0.5);
 expercent=ex2/ex1*100;
 pr1=sum(se1fsave>=max(C2)-0.1 & se1fsave<=max(C2)+0.1); %max
 pr2=sum(se2fsave>=0.2 & se1fsave>=max(C2)-0.1 & se1fsave<=max(C2)+0.1);
 prpercent=pr2/pr1*100;
 pr3=sum(se1fsave>=C12_1(1)-0.1 & se1fsave<=C12_1(1)+0.1); %opt
 pr4=sum(se2fsave>=0.2 & se1fsave>=C12_1(1)-0.1 & se1fsave<=C12_1(1)+0.1);
 prpercent2=pr4/pr3*100;
  
 h=figure;
 hold on
 maxFRC=round(max(se1f)*1.2*10)/10;
 plot(se1fsave,se2fsave,'o','HandleVisibility','off') 
 xlabel('FRC at Tapstand (mg/L)')
 ylabel('FRC at Household (mg/L)')
 axis([0 maxFRC 0 maxFRC])
 plot([0 maxFRC],[0 maxFRC],'k-','HandleVisibility','off')
 plot([0.2 0.2], [0 maxFRC],'r--')
 plot([0.5 0.5], [0 maxFRC],'r--','HandleVisibility','off')
 plot([C12_1(1)-0.1 C12_1(1)-0.1], [0 maxFRC],'g--')
 plot([C12_1(1)+0.1 C12_1(1)+0.1], [0 maxFRC],'g--','HandleVisibility','off')
 plot([max(C2)-0.1 max(C2)-0.1], [0 maxFRC],'b--')
 plot([max(C2)+0.1 max(C2)+0.1], [0 maxFRC],'b--','HandleVisibility','off')
 annotation('textbox',[0.58 0.2 0.2 0.2],'String',sprintf('Existing = %3.0f of %3.0f = %3.1f%% success\nOptimum = %3.0f of %3.0f = %3.1f%% success\nMaximum = %3.0f of %3.0f = %3.1f%% success',ex2,ex1,expercent,pr4,pr3,prpercent2,pr2,pr1,prpercent),'FontSize',8)
 plot([0 maxFRC],[0.2 0.2],'k--','HandleVisibility','off')
 text(maxFRC*0.65,0.12,'Household Water Safety Threshold = 0.2 mg/L','FontSize',8)
 title(sprintf('SWOT Engineering Optimization Model - Empirical Back-Check at approx. 12h follow-up\nDataset: %s\nCode Version: %s',inputFileName,version))
 legend('Existing Guidelines, 0.2 - 0.5 mg/L',sprintf('Proposed Guidelines Optimum, %1.2f - %1.2f mg/L',C12_1(1)-0.1,C12_1(1)+0.1),sprintf('Proposed Guidelines Maximum, %1.2f - %1.2f mg/L',max(C2)-0.1,max(C2)+0.1),'Location', 'NorthWest')
 grid on
 hold off
 saveas (gcf,sprintf('%s/%s_Backcheck.png',output,inputFileName))
 close all
 
 forxls=cell(11,18);
 forxls(1,:)={sprintf('Dataset: %s\nCode Version: %s',inputFileName,version),'Initial guess for k','Initial guess for n','k','n','SSE','R2','Sum of residuals','Relative error','Minimum C(t=12h)','Optimum C(t=12h)','Maximum C(t=12h)','Minimum C(t=15h)','Optimum C(t=15h)','Maximum C(t=15h)','Minimum C(t=24h)','Optimum C(t=24h)','Maximum C(t=24h)'};
 forxls(2)={'90% Training Set'};
 forxls(7)={'10% Test Set'};
 for i=1:5
  forxls(1+i,2:18)={k(i,1) k(i,2) a_1(i,1) a_1(i,2) sse_1(i) R2_1(i) sumres_1(i) SSR_1(i) minC12(i) C12_1(i) maxC12(i) minC15(i) C15_1(i) maxC15(i) minC24(i) C24_1(i) maxC24(i)};
  forxls(6+i,2:18)={k(i,1) k(i,2) a_1(i,1) a_1(i,2) sse_1_test(i) R2_1_test(i) sumres_1_test(i) SSR_1_test(i) minC12(i) C12_1_test(i) maxC12(i) minC15(i) C15_1_test(i) maxC15(i) minC24(i) C24_1_test(i) maxC24(i)};
 end

 
 %forxls=[k a_1 sse_1' R2_1' sumres_1' SSR_1' minC10' C10_1' maxC10' minC24' C24_1' maxC24'; k a_1 sse_1_test' R2_1_test' sumres_1_test' SSR_1_test' minC10' C10_1_test' maxC10' minC24' C24_1_test' maxC24'];
 xlswrite(sprintf('%s/%s_Results.xlsx',output,inputFileName),forxls,'A1:S11');
end

%looking at SSE for all points
function SSE=fun(a,t,f,f0,w)
fpred=(f0.^(1-a(2))+(a(2)-1)*a(1)*t).^(1/(1-a(2)));
SSE=sum(w.*((f-fpred).^2));
end
