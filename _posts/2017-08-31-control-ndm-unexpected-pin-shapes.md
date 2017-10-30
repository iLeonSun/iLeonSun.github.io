---
title: Control NDM unexpected pin shapes
layout: post
section-type: post
comments: true
date: 2017-08-31
category: tool
tags: [icc2_lm,ndm]
excerpt_separator: <!--more-->
---

从ICC2开始, synopsys 为了提高PR工具的速度，引入了一种新格式的库，即NDM(new data model)。NDM 其实就是将logic info 和 physical info合成到一起，NDM有4种view:
1. layout view
2. design view
3. frame view
4. timing view

使用ICC2 library manger 生成NDM时，physical lib 是必须的，可以为lef、gds、oasis、ICC frame，常用的是lef/gds。使用lef时，比较方便，因为lef里含有design info，如site name，cell type，pin direction 等信息（site name有时会需要转成与tech lef一致，`read_lef -convert_sites`）；而使用gds/oasis时，就比较麻烦，这是因为，gds里只有一层层的metal，site name/cell type 这些信息需要用户根据实际指定（marco,pad,corner,filler,cover...), pin name可以从通过trace text得到，而pin direction 则必须从timing lib得到。
<!--more-->

## Problem
碰到的问题是，使用gds作为physical source来产生NDM时，会将每个via cut shape当做termial。  
gds 局部图如下，text 在每层metal上，每层metal之间有width 0.05um spacing 0.08um 的via。  

![gds局部图](/img/2017-08-31_gds.png){:width="70%"}   
extract frame时设了`lib.physical_model.merge_metal_blockage`为true，根据man page，当两块metal之间距离小于spacing threshold (2*min_spacing-min_width)时会被merge，查看techfile，该层min witdh和min spacing分别为0.05和0.08，那么threshold应该为2*0.08-0.05=0.11。而这些via之间间距为0.08，却没有被merge。
这会有什么影响呢？PR时，ICC2里会报如下warning:
~~~
Warning: Cell **** port DVSS09 contains more than 1000000 pins (Number of pins: 1062350).  This may increase routing runtime. (ZRT-565)
~~~
这个warning的意思应该是含有太多的pin shape，或者说这个port 有太多的terminal。
~~~
icc2_shell> sizeof_collection [get_shapes -of [get_ports DVSS09*]]
1059159
icc2_shell> sizeof_collection [get_terminals DVSS09*]
1059159
icc2_shell>
~~~
该warning的manpage如下：
~~~
ZRT-565  
  
NAME  
  
ZRT-565 (warning) Cell %s port %s contains more than %d pins (Number of pins: %d). This may increase routing runtime.  
  
DESCRIPTION  
  
A port contains a large number of pins. This is atypical and may increase routing runtime.  
  
WHAT NEXT  
  
If this is not expected, please reduce the number of pins for the port.
~~~

## Solution
1.`read_gds -trace_option`：尝试改变gds trace option，`pins_only`,`same_layer`都没有效果；  
2.`read_gds -trace_connectivity_limit`: 尝试设trace limit 为1，仍然没有效果；  
3.`file.gds.create_custom_via`:尝试把那些via cut shape当做一整个via，这个变量设为true，runtime大大增加，未等待到结果；  
4.`file.gds.exclude_layers`: 直接把gds里的via layer都exclude。    
在`read_gds`前，`set_app_options -name file.gds.exclude_layers -value { {VIA1 VIA1} {VIA2 VIA2} {VIA3 VIA3} {VIA4 VIA4} {VIA5 VIA5} {VIA6 VIA6} {VIA7 VIA7} }`，让lm忽略所有via layer，果然生成的NDM里没有了那些pin shape。这些via的enclosure没有超出upper/lower metal，所有去掉这些via在route时应该不会引起额外的drc。

## Conclusion
使用GDS作为physical source生成NDM时，design info需要tool自己trace，这个过程有许多变量来控制，要根据实际需要调整这些变量来得到合理的NDM。
