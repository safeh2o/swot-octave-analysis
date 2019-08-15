function engmodel(csvin,sheet,output)
%2 point analysis
clc
format long
pkg load statistics
pkg load windows
pkg load io

%read data
##csv=csvread(csvin);
##csv(1,:)=[];                  %delete header row
  csv=xlsread(csvin,sheet);
  se1tfull=csv(:,4);
  se1f=csv(:,5);
  se2tfull=csv(:,25);
  se2f=csv(:,26);
  se1t=(se1tfull-se1tfull)*24;
  se2t=(se2tfull-se1tfull)*24+24;

se1fsave=se1f;
se2fsave=se2f;
bad=se2fsave<=0 | se1fsave <=0 | isnan(se2fsave);
se1fsave=se1fsave(bad==0);
se2fsave=se2fsave(bad==0);

f01=se1f;
f02=se1f;

%builds a vector of elements that need to be removed from each measurement time
%checks if any concentration is greater than FRC1 by 0.05 and 5%
%also checks if concentrations or times are negative (ie. blank) to remove those elements
bad=se2f>se1f+0.03 | se2f<=0 | se2t<=0 | isnan(se2f) | isnan(se1f) | isnan(se2t);

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
%%
%FRC2 only model 2
##[a_2 sse_2]=fminsearch(@fun5,k,'',t,f,f0,n5,n5only);
##fpred=(f0.^(1-a_2(2))+(a_2(2)-1)*a_2(1)*t).^(1/(1-a_2(2)));
##fpred(fpred<0.03)=0.03;
##sse_2=sum((f-fpred).^2);
##sst_2=sum((f-mean(f)).^2);
##R2_2=1-sse_2/sst_2;
##
##sse_FRC2_2=sum((f(n5only+1:n5only+n5)-fpred(n5only+1:n5only+n5)).^2);
##sst_FRC2_2=sum((f(n5only+1:n5only+n5)-mean(f(n5only+1:n5only+n5))).^2);
##R2_FRC2_2=1-sse_FRC2_2/sst_FRC2_2;
##
##e1=fpred./f;
##e2=f./fpred;
##ee=[e1(e1>e2)-1 e2(e2>=e1)-1];
##en=normpdf(ee,0.5,0.15);
##SSR_2=sum(en);
##
##e1=fpred(n5only+1:n5only+n5)./f(n5only+1:n5only+n5);
##e2=f(n5only+1:n5only+n5)./fpred(n5only+1:n5only+n5);
##ee=[e1(e1>e2)-1 e2(e2>=e1)-1];
##en=normpdf(ee,0.5,0.15);
##SSR_FRC2_2=sum(en);
##
##res=f-fpred;
##sumres_2=sum(res);
##sumres_FRC2_2=sum(res(n5only+1:n5only+n5));
##
##%%
##%relative error model 3
##[a_3 sse_3]=fminsearch(@fun3,k,'',t,f,f0);
##fpred=(f0.^(1-a_3(2))+(a_3(2)-1)*a_3(1)*t).^(1/(1-a_3(2)));
##fpred(fpred<0.03)=0.03;
##sse_3=sum((f-fpred).^2);
##sst_3=sum((f-mean(f)).^2);
##R2_3=1-sse_3/sst_3;
##
##sse_FRC2_3=sum((f(n5only+1:n5only+n5)-fpred(n5only+1:n5only+n5)).^2);
##sst_FRC2_3=sum((f(n5only+1:n5only+n5)-mean(f(n5only+1:n5only+n5))).^2);
##R2_FRC2_3=1-sse_FRC2_3/sst_FRC2_3;
##
##e1=fpred./f;
##e2=f./fpred;
##ee=[e1(e1>e2)-1 e2(e2>=e1)-1];
##en=normpdf(ee,0.5,0.15);
##SSR_3=sum(en);
##
##e1=fpred(n5only+1:n5only+n5)./f(n5only+1:n5only+n5);
##e2=f(n5only+1:n5only+n5)./fpred(n5only+1:n5only+n5);
##ee=[e1(e1>e2)-1 e2(e2>=e1)-1];
##en=normpdf(ee,0.5,0.15);
##SSR_FRC2_3=sum(en);
##
##%%
##%at n=0 model 4
##[a_4 sse_4]=fminsearch(@fun0,0.1,'',t,f,f0);
##fpred=f0-a_4*t;
##fpred(fpred<0.03)=0.03;
##sst_4=sum((f-mean(f)).^2);
##R2_4=1-sse_4/sst_4;
##
##sse_FRC2_4=sum((f(n5only+1:n5only+n5)-fpred(n5only+1:n5only+n5)).^2);
##sst_FRC2_4=sum((f(n5only+1:n5only+n5)-mean(f(n5only+1:n5only+n5))).^2);
##R2_FRC2_4=1-sse_FRC2_4/sst_FRC2_4;
##
##e1=fpred./f;
##e2=f./fpred;
##ee=[e1(e1>e2)-1 e2(e2>=e1)-1];
##en=normpdf(ee,0.5,0.15);
##SSR_4=sum(en);
##
##e1=fpred(n5only+1:n5only+n5)./f(n5only+1:n5only+n5);
##e2=f(n5only+1:n5only+n5)./fpred(n5only+1:n5only+n5);
##ee=[e1(e1>e2)-1 e2(e2>=e1)-1];
##en=normpdf(ee,0.5,0.15);
##SSR_FRC2_4=sum(en);
##
##res=f-fpred;
##sumres_4=sum(res);
##sumres_FRC2_4=sum(res(n5only+1:n5only+n5));
##
##%%
##%at n=1 model 5
##[a_5 sse_5]=fminsearch(@fun1,0.1,'',t,f,f0);
##fpred=f0.*exp(-a_5*t);
##fpred(fpred<0.03)=0.03;
##sst_5=sum((f-mean(f)).^2);
##R2_5=1-sse_5/sst_5;
##
##sse_FRC2_5=sum((f(n5only+1:n5only+n5)-fpred(n5only+1:n5only+n5)).^2);
##sst_FRC2_5=sum((f(n5only+1:n5only+n5)-mean(f(n5only+1:n5only+n5))).^2);
##R2_FRC2_5=1-sse_FRC2_5/sst_FRC2_5;
##
##e1=fpred./f;
##e2=f./fpred;
##ee=[e1(e1>e2)-1 e2(e2>=e1)-1];
##en=normpdf(ee,0.5,0.15);
##SSR_5=sum(en);
##
##e1=fpred(n5only+1:n5only+n5)./f(n5only+1:n5only+n5);
##e2=f(n5only+1:n5only+n5)./fpred(n5only+1:n5only+n5);
##ee=[e1(e1>e2)-1 e2(e2>=e1)-1];
##en=normpdf(ee,0.5,0.15);
##SSR_FRC2_5=sum(en);
##
##res=f-fpred;
##sumres_5=sum(res);
##sumres_FRC2_5=sum(res(n5only+1:n5only+n5));
##
##%%
##%at n=2 model 6
##[a_6 sse_6]=fminsearch(@fun2,0.1,'',t,f,f0);
##fpred=(f0.^-1+a_6*t).^-1;
##fpred(fpred<0.03)=0.03;
##sst_6=sum((f-mean(f)).^2);
##R2_6=1-sse_6/sst_6;
##
##sse_FRC2_6=sum((f(n5only+1:n5only+n5)-fpred(n5only+1:n5only+n5)).^2);
##sst_FRC2_6=sum((f(n5only+1:n5only+n5)-mean(f(n5only+1:n5only+n5))).^2);
##R2_FRC2_6=1-sse_FRC2_6/sst_FRC2_6;
##
##e1=fpred./f;
##e2=f./fpred;
##ee=[e1(e1>e2)-1 e2(e2>=e1)-1];
##en=normpdf(ee,0.5,0.15);
##SSR_6=sum(en);
##
##e1=fpred(n5only+1:n5only+n5)./f(n5only+1:n5only+n5);
##e2=f(n5only+1:n5only+n5)./fpred(n5only+1:n5only+n5);
##ee=[e1(e1>e2)-1 e2(e2>=e1)-1];
##en=normpdf(ee,0.5,0.15);
##SSR_FRC2_6=sum(en);
##
##res=f-fpred;
##sumres_6=sum(res);
##sumres_FRC2_6=sum(res(n5only+1:n5only+n5));
##
##%%
##%weighted approach model 7
##resmod(resmod<1e-6)=1;
##w=1./resmod.^2;
##
##k=[0.001 2];
##[a_7 sse_7]=fminsearch(@fun,k,'',t,f,f0,w);
##fpred=(f0.^(1-a_7(2))+(a_7(2)-1)*a_7(1)*t).^(1/(1-a_7(2)));
##fpred(fpred<0.03)=0.03;
##sse_7=sum((f-fpred).^2);
##sst_7=sum((f-mean(f)).^2);
##R2_7=1-sse_7/sst_7;
##
##sse_FRC2_7=sum((f(n5only+1:n5only+n5)-fpred(n5only+1:n5only+n5)).^2);
##sst_FRC2_7=sum((f(n5only+1:n5only+n5)-mean(f(n5only+1:n5only+n5))).^2);
##R2_FRC2_7=1-sse_FRC2_7/sst_FRC2_7;
##
##e1=fpred./f;
##e2=f./fpred;
##ee=[e1(e1>e2)-1 e2(e2>=e1)-1];
##en=normpdf(ee,0.5,0.15);
##SSR_7=sum(en);
##
##e1=fpred(n5only+1:n5only+n5)./f(n5only+1:n5only+n5);
##e2=f(n5only+1:n5only+n5)./fpred(n5only+1:n5only+n5);
##ee=[e1(e1>e2)-1 e2(e2>=e1)-1];
##en=normpdf(ee,0.5,0.15);
##SSR_FRC2_7=sum(en);
##
##res=f-fpred;
##sumres_7=sum(res);
##sumres_FRC2_7=sum(res(n5only+1:n5only+n5));
##
##%%
##%weighted approach, w=2 for FRC2, model 8
##w=0.75*ones(1,length(t));
##w(n5only+1:n5only+n5)=2;
##
##k=[0.001 2];
##[a_8 sse_8]=fminsearch(@fun,k,'',t,f,f0,w);
##fpred=(f0.^(1-a_8(2))+(a_8(2)-1)*a_8(1)*t).^(1/(1-a_8(2)));
##fpred(fpred<0.03)=0.03;
##sse_8=sum((f-fpred).^2);
##sst_8=sum((f-mean(f)).^2);
##R2_8=1-sse_8/sst_8;
##
##sse_FRC2_8=sum((f(n5only+1:n5only+n5)-fpred(n5only+1:n5only+n5)).^2);
##sst_FRC2_8=sum((f(n5only+1:n5only+n5)-mean(f(n5only+1:n5only+n5))).^2);
##R2_FRC2_8=1-sse_FRC2_8/sst_FRC2_8;
##
##e1=fpred./f;
##e2=f./fpred;
##ee=[e1(e1>e2)-1 e2(e2>=e1)-1];
##en=normpdf(ee,0.5,0.15);
##SSR_8=sum(en);
##
##e1=fpred(n5only+1:n5only+n5)./f(n5only+1:n5only+n5);
##e2=f(n5only+1:n5only+n5)./fpred(n5only+1:n5only+n5);
##ee=[e1(e1>e2)-1 e2(e2>=e1)-1];
##en=normpdf(ee,0.5,0.15);
##SSR_FRC2_8=sum(en);
##
##res=f-fpred;
##sumres_8=sum(res);
##sumres_FRC2_8=sum(res(n5only+1:n5only+n5));
##
##%%
##%weighted approach, w=4 for FRC2, model 9
##w=0.25*ones(1,length(t));
##w(n5only+1:n5only+n5)=4;
##
##k=[0.001 2];
##[a_9 sse_9]=fminsearch(@fun,k,'',t,f,f0,w);
##fpred=(f0.^(1-a_9(2))+(a_9(2)-1)*a_9(1)*t).^(1/(1-a_9(2)));
##fpred(fpred<0.03)=0.03;
##sse_9=sum((f-fpred).^2);
##sst_9=sum((f-mean(f)).^2);
##R2_9=1-sse_9/sst_9;
##
##sse_FRC2_9=sum((f(n5only+1:n5only+n5)-fpred(n5only+1:n5only+n5)).^2);
##sst_FRC2_9=sum((f(n5only+1:n5only+n5)-mean(f(n5only+1:n5only+n5))).^2);
##R2_FRC2_9=1-sse_FRC2_9/sst_FRC2_9;
##
##e1=fpred./f;
##e2=f./fpred;
##ee=[e1(e1>e2)-1 e2(e2>=e1)-1];
##en=normpdf(ee,0.5,0.15);
##SSR_9=sum(en);
##
##e1=fpred(n5only+1:n5only+n5)./f(n5only+1:n5only+n5);
##e2=f(n5only+1:n5only+n5)./fpred(n5only+1:n5only+n5);
##ee=[e1(e1>e2)-1 e2(e2>=e1)-1];
##en=normpdf(ee,0.5,0.15);
##SSR_FRC2_9=sum(en);
##
##res=f-fpred;
##sumres_9=sum(res);
##sumres_FRC2_9=sum(res(n5only+1:n5only+n5));
##
##%%
end
##forxls=[a_1(1) a_1(2) sse_1 sse_FRC2_1 R2_1 R2_FRC2_1 sumres_1 sumres_FRC2_1 SSR_1 SSR_FRC2_1; a_2(1) a_2(2) sse_2 sse_FRC2_2 R2_2 R2_FRC2_2 sumres_2 sumres_FRC2_2 SSR_2 SSR_FRC2_2; a_3(1) a_3(2) sse_3 sse_FRC2_3 R2_3 R2_FRC2_3 sumres_3 sumres_FRC2_3 SSR_3 SSR_FRC2_3;  a_4 0 sse_4 sse_FRC2_4 R2_4 R2_FRC2_4 sumres_4 sumres_FRC2_4 SSR_4 SSR_FRC2_4; a_5 1 sse_5 sse_FRC2_5 R2_5 R2_FRC2_5 sumres_5 sumres_FRC2_5 SSR_5 SSR_FRC2_5; a_6 2 sse_6 sse_FRC2_6 R2_6 R2_FRC2_6 sumres_6 sumres_FRC2_6 SSR_6 SSR_FRC2_6; a_7(1) a_7(2) sse_7 sse_FRC2_7 R2_7 R2_FRC2_7 sumres_7 sumres_FRC2_7 SSR_7 SSR_FRC2_7; a_8(1) a_8(2) sse_8 sse_FRC2_8 R2_8 R2_FRC2_8 sumres_8 sumres_FRC2_8 SSR_8 SSR_FRC2_8; a_9(1) a_9(2) sse_9 sse_FRC2_9 R2_9 R2_FRC2_9 sumres_9 sumres_FRC2_9 SSR_9 SSR_FRC2_9];

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
 
## ex1=sum(se1fsave>=0.2 & se1fsave<=0.5)
## ex2=sum(se2fsave>=0.2 & se1fsave>=0.2 & se1fsave<=0.5)
## ex2/ex1
## pr1=sum(se1fsave>=C24_1(1) & se1fsave<=max(C))
## pr2=sum(se2fsave>=0.2 & se1fsave>=C24_1(1) & se1fsave<=max(C))
## pr2/pr1
 forxls=[k a_1 sse_1' sse_FRC2_1' R2_1' R2_FRC2_1' sumres_1' sumres_FRC2_1' SSR_1' SSR_FRC2_1' minC10' C10_1' maxC10' minC24' C24_1' maxC24'; k a_1 sse_1_test' sse_FRC2_1_test' R2_1_test' R2_FRC2_1_test' sumres_1_test' sumres_FRC2_1_test' SSR_1_test' SSR_FRC2_1_test' minC10' C10_1_test' maxC10' minC24' C24_1_test' maxC24'];
 csvwrite(sprintf('%s/Results.csv',output),forxls);
 xlswrite(sprintf('%s/Results.xlsx',output),forxls,'C2:T11');
end

%looking at SSE for all points
function SSE=fun(a,t,f,f0,w)
fpred=(f0.^(1-a(2))+(a(2)-1)*a(1)*t).^(1/(1-a(2)));
SSE=sum(w.*((f-fpred).^2));
end

%at n=0
function SSE=fun0(a,t,f,f0)
fpred=f0-a*t;
SSE=sum((f-fpred).^2);
end

%at n=1
function SSE=fun1(a,t,f,f0)
fpred=f0.*exp(-a*t);
SSE=sum((f-fpred).^2);
end

%at n=2
function SSE=fun2(a,t,f,f0)
fpred=(f0.^-1+a*t).^-1;
SSE=sum((f-fpred).^2);
end


%only looking at SSE in FRC2
function SSE_5=fun5(a,t,f,f0,n5,n)
fpred=(f0.^(1-a(2))+(a(2)-1)*a(1)*t).^(1/(1-a(2)));
SSE_5=sum((f(n+1:n+n5)-fpred(n+1:n+n5)).^2);
end

%relative error for all points
function SSE_r=fun3(a,t,f,f0)
fpred=(f0.^(1-a(2))+(a(2)-1)*a(1)*t).^(1/(1-a(2)));
e1=fpred./f;
e2=f./fpred;

SSE_r=sum([e1(e1>e2)-1 e2(e2>=e1)-1]);
end