---
title: Debug PrimeTime Crash Issue In A Restored Session
layout: post
section-type: post
comments: true
date: 2017-11-22
category: STA
tags: [PT]
excerpt_separator: <!--more-->
---
之前一直用的是2015版本的PrimeTime，最近项目中有path margin约束，需要更新到2016.12sp1版本的PrimeTime。使用该版本时，由于软件feature变化，一直碰到crash的问题，最近才终于发现根源。   <!--more-->
## 1. Issue
STA刚开始时，我习惯的做法是先DMSA flow来跑一下全部signoff secnario，save_session来保存（由于license/mem/cpu等限制，可能要分多次跑DMSA），然后选出timing最差的某些corner来fix。  
这次，更新到新版本后，restore session后`update_timing`和`fix_eco_timing`等cmd经常会导致session crash。  
而且，crash前不会有warning/error等提示，直接是一堆stack trace。  

## 2.Debug
首先，我对通过多次single-scenario run来得到多个session; restore这些session后，无论是`update_timing`,`fix_eco_timing`或者其他cmd都没有引起session crash。  
**这就说明，引起crash的不是database，而是DMSA。**  
然后，**新建了一个工作目录**，多次DMSA跑multi-scenarios; restore这些session，发现只有第一次的那些session可以正常，其余session还是会crash。  
就是说，比如第一次DMSA跑了:s1,s2,s3;第二次跑了：s4,s5,s6; 第三次跑了：s7,s8,s9。仅s1/s2/s3可以restore正常工作，没有crash。  
于是，我再次DMSA跑了:s1,s2,s3，为了和第一次区分，就叫他们为：s1_2,s2_2,s3_2。但是s1_2/s2_2/s3_2 restore后也会crash。  
虽然s1/s1_1的cmd/constraint等完全一致，但是s1不会crash，s1_1会crash。  
接下来，就要比较s1和s1_1这两个session到底有什么差异了。  
PT保存的session不可读，但是lib_mapping/readme是可读的。  
比较了这两个file，并未发现有什么不同。  
就在我以为此路不通时，忽然发现session里有两个link file。而且不同session的file都link到同样的file。
```
##隐path，仅示意
mod29 -> /foo/bar/DMSA_work/common_data/a/mod29
nmp29 -> /foo/bar/DMSA_work/common_data/a/nmp29
```
`save_session`时为了节约硬盘空间，不同session之间可以共用信息，这部分就是存在common_data下。  
那么问题就可以定位到DMSA common data上。  
为何不是同一次DMSA的session会共用同样的data？  
查看了旧版本的common data，每次DMSA的命名是不一样的。所以这应该就是root cause。

## 3.Fix
老版本的PT在save_session时，common data是这样的：
```
% ls -rt
a  f  k  p  u  z   ae  aj  ao  at  ay   aad  aaq  aaf  aak  aax   aaac  aaah  aaam  aaar  aaaw   aaaab  aaaag  aaaal  aaaaq  aaaav  aaaaaa  aaaaaf  aaaaak
b  g  l  q  v  aa  af  ak  ap  au  az   aam  aar  aag  aal  aay   aaad  aaai  aaan  aaas  aaax   aaaac  aaaah  aaaam  aaaar  aaaaw  aaaaab  aaaaag  tracking_file
c  h  m  r  w  ab  ag  al  aq  av  aaa  aan  aas  aah  aau  aaz   aaae  aaaj  aaao  aaat  aaay   aaaad  aaaai  aaaan  aaaas  aaaax  aaaaac  aaaaah
d  i  n  s  x  ac  ah  am  ar  aw  aab  aao  aat  aai  aav  aaaa  aaaf  aaak  aaap  aaau  aaaz   aaaae  aaaaj  aaaao  aaaat  aaaay  aaaaad  aaaaai
e  j  o  t  y  ad  ai  an  as  ax  aac  aap  aae  aaj  aaw  aaab  aaag  aaal  aaaq  aaav  aaaaa  aaaaf  aaaak  aaaap  aaaau  aaaaz  aaaaae  aaaaaj
```
DMSA save_session时，common data下会从a到z开始命名，用完了就用aa-az，aaa-aaz，aaaa-aaaz以此类推。  
就是说，每次DMSA在save session时会查看下common data目录，如果已经有data了，就会用新的名字来保存，以保证不覆盖已存的data。  
但是2016版本的PT，在save seesion时，并不会用新名字来保存common data，而且，也不会覆盖已存在的data。或者该说，它发现已经有存在的data，它就不会重新保存，所以common data下仅会保存着第一次产生的data......   
所以，只有第一次保存的session可以正常restore。  
那么，work around可以是每次把common data保存到不同的目录下。common data dir是怎么决定的呢？  
`save_session`的manpage里有解释：
```
When save_session is called in a distributed multi-scenario analysis (DMSA) run, certain data, such as parasitic and physical DB information, are stored in a common data directory named common_data. 
The images saved by each scenario contain softlinks to the data in this common data directory to avoid a duplication of storage of the data that scenarios share in common. 
When save_session is issued directly to the master session, the common data directory is created in the specified image directory. 
When save_session is issued to the slaves via remote_execute, the location of the common data directory is based on whether the image directory specified to the command is relative or absolute:

For absolute paths, the common data is located in the parent directory of the specified directory. All scenario images should share the same parent directory to maximise sharing.

For relative paths, the common data directory is located directly under the multi-scenario working directory.

To execute a multi_scenario save_session with common data sharing disabled, use the -disable_common_data_sharing option.
```

所以，`save_session`时指定绝对路径就可以把common data保存到session的上一级目录，而不是master working dir，这样就不会有多次DMSA的common data冲突的情况。
