---
title: NLDM vs. CCS
layout: post
section-type: post
comments: true
date: 2017-10-25
category: STA
tags: 
excerpt_separator: <!--more-->
---
上篇里提到了，一些负面效应在advanced node下越来越明显，这些效应也使传统的NLDM model越来越不精确。Synopsys提出了Composite Current Source(CCS)，CCS是基于电流源模型，集timing/power/noise于一体，精确度更高，与SPICE的误差可以达到±2%。<!--more-->  

## 1. cell model
集成电路设计是典型的hierarchical design：PMOS/NMOS --> std cell --> design module --> block --> chip。每一次的低层抽象过程，都要抽取出logic和physical信息，以供高层使用。  
physical上的抽象，一般是def/lef/frame等，这些都是对GDS的简化。  
logic上，一般会包括timing、power、noise等信息。  
从最底层的MOS管抽象出std cell，就是cell model过程; 从MOS管提取出的timing、power、noise信息写入lib/db file，供上层做STA/SPA/SNA等分析。90nm以前，一般用NLDM/NLPM/NLNM(Nonlinear Delay/Power/Noise Model)。但是advanced node下，NLDM的精确度差，常用的model有:CCS(synopsys) 和 ECS(cadence)。   
Block的logic信息也要抽象出来供top使用，常见的抽象block timing模型有：block abstract model(BAM)、extract timing model(ETM)、interface logic models(ILM)等。   

## 2. NLDM
Cell model过程是把一个std cell看成block box，只考虑其input/output pin。其input pin对外部是receiver; output pin对外部是driver。Cell model都需要对receiver/driver分别建立模型，得到的模型结果越接近真实值，则精确度更高。  
  
![NLDM driver/receiver model](/img/2017-10-25_nldm.png)
  
NLDM的driver model是一个内阻恒定的电压源，即输出电压是时间的线性函数，V(t)。这是可以理解的，因为对于driver model，仅考虑stdcell最后一个MOS管，回忆一下，MOS管在导通时要经过多子减少、反型、少子继续积累至饱和，在I-V曲线上就表现为截止区、线性区和饱和区。在线性区上，MOS管电阻可以近似的看成定值(只是近似，其实除了线性关系，还有个二次函数关系,所以电阻其实是逐渐变大的)。这段线性区的过程，在数字集成电路中，就是transition time。所以，NLDM模型认为cell outout pin从0到1过程中，V是线性地从0到VDD。  
NLDM的receiver model是一个恒定的input cap。  
NLDM虽然很简单，但是随着工艺节点下降，金属电阻、寄生电容都越来越大，其精确度也就变差。对于NLDM driver model，当其后面的金属电阻/电容变大时，线性区的电阻是变大的，而且，V越接近VDD，电阻值越大，所以其实driver transition time 变大，cell delay变大。对于NLDM receiver model，在advanced node下，Miller效应影响更明显，单一的input cap也无法正确表征。如下图，可以看出在0.6V前后，曲线曲率明显不同，对应cap值分别为23/31，这无法用单一的input cap表示。  
![NLDM input cap](/img/2017-10-25_ccs_input_cap.png)

## 3. CCS
CCS就是为了解决这些偏差而生的。   
  
![CCS driver/receiver model](/img/2017-10-25_ccs.png)
  
CCS driver model是一个非线性复合电流源，电流随电压和时间而变化，I(t,V)，可以更精确地处理高电感负载。不仅如此，CCS dirver还能更好地处理非单调波形。   
CCS receiver model是由两个cap值表示，它们随着transition而变化。C1,C2分别是transition前后半段的cap值。比如input pin的trip points是30%和70%，那么(30%,50%)这段时间的cap值为C1，(50%,70%)这段时间的cap值为C2，STA tool会动态选择cap值。如下图，C1/C2值还是能很好的拟合实际情形。   
![NLDM input cap](/img/2017-10-25_ccs_input_cap.png)

另外，CCS lib/db里，可以同时含timing/power/noise信息。CCS lib里会看到有ccsn_first_stage/ccsn_last_stage group，分别是最前/后级管子受noise的影响。
