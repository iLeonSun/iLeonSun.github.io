---
title: Virtual Clock
layout: post
section-type: post
comments: true
date: 2018-03-30
category: STA
tags: 
excerpt_separator: <!--more-->
---
## 1. What is virtual clock

>Virtual Clock: 没有定义时钟源的时钟
Real Clock: 定义了时钟源的时钟。

<!--more-->
Virtual clock与real clock的区别就在于是否有source，real clock有实实在在的source pin/port，沿着source可以trace到clock sink，可以对real clock做CTS；而virtual clock不行。  
定义Real/Virtual clock cmd 如下：
```
## real clock, with source pin/port
create_clock -name "CLK" -period 10 -waveform [0 5] [get_ports clk]
## virtual clock
create_clock -name "VirCLK" -period 10 -waveform [0 5]
```

## 2. Purpose of Virtual Clock
简单地说，Virtual clock就是用来帮助我们约束IO的。一图胜千言，请看下面的示意图(ps:安利online画电路图网站[schemeit](https://www.digikey.com/schemeit))：  
![vir clk schematic](/img/2018-03-30-vir_clk_schematic.png)

对于TOP，4个FF源于同一个clk，它们都是同步的，所以FF1->FF2，FF3->FF4这两条跨block的path都需要检查timing；而对于BLOCK，这两条path是看不见的，它只能看到A->FF2 和 FF3->B的path，即block内部看到的path比真实path要短。  
这样就需要对input port A 设input delay约束，delay value为从FF1/CP到A的delay；对output port B 设output delay约束，delay value为从B到FF4/D的delay。  
这样一来，data path上就能正确反映实际full path了，那么clock path呢？  
对于FF1/CP-->FF2/D这条full path，在BLOCK内部，capture pin FF2/CP的latency可以通过clk source latency + clk network latency来得到，source latency是外部CLK source到BLOCK CLK port的delay，可以用`set_clock_latency`约束；network latency是从CLK port 到FF2/CP的latency，这部分就是CTS后clock tree的长度。  
但是FF1/CP在BLOCK外部，无法获得其launch latency，如果不加约束，CTS后，由于launch和capture之间的skew，timing很难meet(in2reg hold，reg2out setup)。   
那么如何约束FF1/CP或者FF4/CP的clk latency呢？  
**这就是virtual clock的真正用意，定义virtual clk，然后通过反标virtual clk的source latency来约束FF1/CP或FF4/CP的clk latency。**   
到这里我们就会发现，其实FF1/CP->FF2/D这条同一个clk约束的full path，其实被分成了vir clk和clk两个同步clk的跨clock domain之间的约束了。  



