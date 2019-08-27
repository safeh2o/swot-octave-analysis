function engmodel(csvin,sheet,output)
%Engineering Optimization Model for SWOT
%Version 1
%Saad Ali
clc
format long
pkg load statistics
pkg load io

%read data
##csv=csvread(csvin);
##csv(1,:)=[];                  %delete header row
[numdata strdata]=xlsread(csvin,sheet);
for i=1:size(strdata,1)-1
  if ~isempty(strdata{i+1,6})
    hr=str2num(strdata{i+1,6}(12:13));
    minute=str2num(strdata{i+1,6}(15:16));
    second=str2num(strdata{i+1,6}(18:19));
    se1tfull(i)=hr+minute/60+second/3600; 
  else
    se1tfull(i)=-1;
  end
  
  
  if ~isempty(strdata{i+1,30})
    hr=str2num(strdata{i+1,30}(12:13));
    minute=str2num(strdata{i+1,30}(15:16));
    second=str2num(strdata{i+1,30}(18:19));
    se2tfull(i)=hr+minute/60+second/3600;
  else
    se2tfull(i)=-1;
  end
  
end
se1f=numdata(:,10);
se2f=numdata(:,45);
se1tfull=se1tfull';
se2tfull=se2tfull';

se1t=(se1tfull-se1tfull);
se2t=(se2tfull-se1tfull);

se1fsave=se1f;
se2fsave=se2f;
bad=se2fsave<=0 | se1fsave <=0 | isnan(se2fsave) | se1tfull<0 | se2tfull<0;
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

  C10_1(i)=(0.2^(1-a_1(i,2))-(a_1(i,2)-1)*a_1(i,1)*10)^(1/(1-a_1(i,2)));
  C24_1(i)=(0.2^(1-a_1(i,2))-(a_1(i,2)-1)*a_1(i,1)*24)^(1/(1-a_1(i,2)));
  
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

  C10_1_test(i)=(0.2^(1-a_1(i,2))-(a_1(i,2)-1)*a_1(i,1)*10)^(1/(1-a_1(i,2)));
  C24_1_test(i)=(0.2^(1-a_1(i,2))-(a_1(i,2)-1)*a_1(i,1)*24)^(1/(1-a_1(i,2)));
end

  kmax=3*round(100*a_1(i,1))/100;
  fpred=[];
  for ii=1:301
    for j=1:301
      a1=(ii-1)*0.01;    %0<n<3
      a2=(j-1)*kmax/300;   %0<k<kmax
      if a1==1
        fpred=f0_full.*exp(-a2*t_full);
        C10(ii,j)=0.2/exp(-a2*10);
        C24(ii,j)=0.2/exp(-a2*24);
      else
        fpred=(f0_full.^(1-a1)+(a1-1)*a2*t_full).^(1/(1-a1));
        C10(ii,j)=(0.2^(1-a1)-(a1-1)*a2*10)^(1/(1-a1));
        C24(ii,j)=(0.2^(1-a1)-(a1-1)*a2*24)^(1/(1-a1));
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
  C2=C10(sse1<minsse*1.05);
  minC10(1:5)=min(C2);
  maxC10(1:5)=max(C2);
  minpoint=find(C24==min(C));
  minK=floor(minpoint/301)*kmax/300;
  minN=mod(minpoint-1,301)*0.01;
  maxpoint=find(C24==max(C));
  maxK=floor(maxpoint/301)*kmax/300;
  maxN=mod(maxpoint-1,301)*0.01;
  optpoint=find(sse1==minsse);
  optK=floor(optpoint/301)*kmax/300;
  optN=mod(optpoint-1,301)*0.01;
  
  h=figure;
  contour(0:kmax/300:kmax,0:0.01:3,sse1,minsse*[1.05:0.05:2])
  hold on
  xlabel('k (hr-1)')
  ylabel('n (rate order)')
  p(1)=plot(optK,optN,'kx');
  p(2)=plot(minK,minN,'bx');
  p(3)=plot(maxK,maxN,'rx');
  legend([p(1) p(2) p(3)],'Optimum Solution','Minimum Prediction for C0','Maximum Prediction for C0','Location','northwest')
  hold off
  saveas (gcf,sprintf('%s/contour.png',output))
  
 h=figure;
 hold on
 maxFRC=round(max(se1f)*1.2*10)/10;
 plot(se1f,se2f,'o') 
 xlabel('FRC at Tapstand')
 ylabel('FRC at Household')
 axis([0 maxFRC 0 maxFRC])
 plot([0 maxFRC],[0 maxFRC],'k-')
 plot([C24_1(1) C24_1(1)], [0 maxFRC],'g--')
 plot([max(C) max(C)], [0 maxFRC],'g--')
 plot([0.2 0.2], [0 maxFRC],'r--')
 plot([0.5 0.5], [0 maxFRC],'r--')
 annotation('textbox',[0.31 0.8 0.1 0.1],'String',sprintf('Existing\nGuidelines'),'FontSize',8)
 annotation('textbox',[0.42 0.8 0.1 0.1],'String',sprintf('Proposed\nGuidelines'),'FontSize',8)
 plot([0 maxFRC],[0.2 0.2],'k--')
 grid on
 hold off
 saveas (gcf,sprintf('%s/backcheck.png',output))
 close all
 
 forxls=cell(11,15);
 forxls(1,:)={'','Initial guess for k','Initial guess for n','k','n','SSE','R2','Sum of residuals','Relative error','Minimum C(t=10h)','Optimum C(t=10h)','Maximum C(t=10h)','Minimum C(t=24h)','Optimum C(t=24h)','Maximum C(t=24h)'};
 forxls(2)={'90% Training Set'};
 forxls(7)={'10% Test Set'};
 for i=1:5
     forxls(1+i,2:15)={k(i,1) k(i,2) a_1(i,1) a_1(i,2) sse_1(i) R2_1(i) sumres_1(i) SSR_1(i) minC10(i) C10_1(i) maxC10(i) minC24(i) C24_1(i) maxC24(i)};
   forxls(6+i,2:15)={k(i,1) k(i,2) a_1(i,1) a_1(i,2) sse_1_test(i) R2_1_test(i) sumres_1_test(i) SSR_1_test(i) minC10(i) C10_1_test(i) maxC10(i) minC24(i) C24_1_test(i) maxC24(i)};
 end

 %forxls=[k a_1 sse_1' R2_1' sumres_1' SSR_1' minC10' C10_1' maxC10' minC24' C24_1' maxC24'; k a_1 sse_1_test' R2_1_test' sumres_1_test' SSR_1_test' minC10' C10_1_test' maxC10' minC24' C24_1_test' maxC24'];
 xlswrite(sprintf('%s/Results.xlsx',output),forxls,'A1:S11');
end

%looking at SSE for all points
function SSE=fun(a,t,f,f0,w)
fpred=(f0.^(1-a(2))+(a(2)-1)*a(1)*t).^(1/(1-a(2)));
SSE=sum(w.*((f-fpred).^2));
end
