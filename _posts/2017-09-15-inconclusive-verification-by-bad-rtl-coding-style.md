---
title: hard verification by bad RLT coding style
layout: post
section-type: post
comments: true
date: 2017-09-15
category: tool
tags: [verification,formality]
excerpt_separator: <!--more-->
---
最近项目中碰到一个hard verification，有11个点inconclusive，属于同一个module下。由于RTL是加密的，无法获知这个module的内容，这也给debug带来了一定麻烦。
<!--more-->
~~~
**************************************************
Report         : aborted_points

Reference      : r:/WORK/**
Implementation : i:/WORK/**
Version        : L-2016.03-SP5
Date           : Sat Sep  2 15:44:52 2017
**************************************************

11 Aborted compare points:
       0 Loop  (driven by a potentially state-holding asynchronous loop)
      11 Hard  (too complex to solve)

 Hard :  Ref  DFF        r:/WORK/**/**/**/**/bar1avg4_3d_reg_10_
         Impl DFF        i:/WORK/**/**/**/**/bar1avg4_3d_reg_10_

 Hard :  Ref  DFF        r:/WORK/**/**/**/**/bar1avg4_3d_reg_11_
         Impl DFF        i:/WORK/**/**/**/**/bar1avg4_3d_reg_11_

 Hard :  Ref  DFF        r:/WORK/**/**/**/**/bar1avg4_3d_reg_8_
         Impl DFF        i:/WORK/**/**/**/**/bar1avg4_3d_reg_8_

 Hard :  Ref  DFF        r:/WORK/**/**/**/**/bar1avg4_3d_reg_9_
         Impl DFF        i:/WORK/**/**/**/**/bar1avg4_3d_reg_9_

 Hard :  Ref  DFF        r:/WORK/**/**/**/**/foosum_3d_reg_16___foosum_3d_reg_15___foosum_3d_reg_14___foosum_3d_reg_13___foosum_3d_reg_12___foosum_3d_reg_11___foosum_3d_reg_10___foosum_3d_reg_9_/\*dff.00.0\*
         Impl DFF        i:/WORK/**/**/**/**/foosum_3d_reg_16___foosum_3d_reg_15___foosum_3d_reg_14___foosum_3d_reg_13___foosum_3d_reg_12___foosum_3d_reg_11___foosum_3d_reg_10___foosum_3d_reg_9_/\*dff.00.0\*

 Hard :  Ref  DFF        r:/WORK/**/**/**/**/foosum_3d_reg_16___foosum_3d_reg_15___foosum_3d_reg_14___foosum_3d_reg_13___foosum_3d_reg_12___foosum_3d_reg_11___foosum_3d_reg_10___foosum_3d_reg_9_/\*dff.00.1\*
         Impl DFF        i:/WORK/**/**/**/**/foosum_3d_reg_16___foosum_3d_reg_15___foosum_3d_reg_14___foosum_3d_reg_13___foosum_3d_reg_12___foosum_3d_reg_11___foosum_3d_reg_10___foosum_3d_reg_9_/\*dff.00.1\*
~~~
## Debug
使用`analyze_points`发现都是同一个datapath 被rejected, formality 也给出了建议。  

~~~
fm_shell (verify)> analyze_points r:/WORK/**/**/**/**/bar1avg4_3d_reg_10_ 
Found 1 Rejected Datapath Guidance Module
--------------------------------
These modules contain cells that may be related to
rejected datapath guidance.
--------------------------------
r:/WORK/**_tdedgdet_M_AVG0_M_TYPE0_0 in file ***/**/**/**.v.e
    Module with rejected datapath guidance on cell(s):
        r:/WORK/**_tdedgdet_M_AVG0_M_TYPE0_0/DP_OP_1054J26_124_1439
     Use 'report_svf_operation { 67437 }' for more information.
     Try adding the following command(s) to your Design Compiler script right before the first compile_ultra command:
          current_design **
          set_verification_priority [ get_cells { **/**/**/add_134952 **/**/**/add_134952_2 **/**/**/add_134952_3 **/**/**/add_134952_4 **/**/**/add_134953 **/**/**/add_134953_2 **/**/**/add_134953_3 **/**/**/add_134953_4 **/**/**/add_134954 **/**/**/add_134954_2 **/**/**/add_134954_3 **/**/**/add_134954_4 **/**/**/add_134955 **/**/**/add_134955_2 **/**/**/add_134955_3 **/**/**/add_134955_4 **/**/**/add_134956 **/**/**/add_134956_10 **/**/**/add_134956_11 **/**/**/add_134956_12 **/**/**/add_134956_13 **/**/**/add_134956_14 **/**/**/add_134956_15 **/**/**/add_134956_2 **/**/**/add_134956_3 **/**/**/add_134956_4 **/**/**/add_134956_5 **/**/**/add_134956_6 **/**/**/add_134956_7 **/**/**/add_134956_8 **/**/**/add_134956_9 **/**/**/add_134961 **/**/**/add_134961_10 **/**/**/add_134961_11 **/**/**/add_134961_12 **/**/**/add_134961_13 **/**/**/add_134961_14 **/**/**/add_134961_15 **/**/**/add_134961_16 **/**/**/add_134961_17 **/**/**/add_134961_18 **/**/**/add_134961_19 **/**/**/add_134961_2 **/**/**/add_134961_20 **/**/**/add_134961_21 **/**/**/add_134961_22 **/**/**/add_134961_23 **/**/**/add_134961_24 **/**/**/add_134961_3 **/**/**/add_134961_4 **/**/**/add_134961_5 **/**/**/add_134961_6 **/**/**/add_134961_7 **/**/**/add_134961_8 **/**/**/add_134961_9 } ]
          
          current_design **

-----------
--------------------------------
****************************************************************************************
Analysis Completed

~~~
看看SVF里的67437 operation是什么：
~~~

fm_shell (verify)> report_svf_operation { 67437 }
**************************************************
Report         : svf_operation
                 67437 

Reference      : r:/WORK/**
Implementation : i:/WORK/**
Version        : L-2016.03-SP5
Date           : Thu Aug 31 18:27:18 2017
**************************************************

## SVF Operation 67437 (Line: 1926568) - datapath.  Status: rejected
## Operation Id: 67437
guide_datapath \
  -design { **_tdedgdet_M_AVG0_M_TYPE0_0 } \
  -datapath { DP_OP_1054J26_124_1439 } \
  -body { **_tdedgdet_M_AVG0_M_TYPE0_0_DP_OP_1054J26_124_1439_J26_0 } 

Info:  guide_datapath 67437 (Line: 1926568)  Pre-verification of r:/WORK/**_tdedgdet_M_AVG0_M_TYPE0_0/DP_OP_1054J26_124_1439 INCONCLUSIVE.
~~~
好像并不能看出太多内容。但是我们可以从formality给的建议里看出，这些cell都是adder。需要注意的是，formality指出的cell name 是在第一次`compile_ultra`之前的，也就是说，这些cell name是从RTL转成GTECH网表时的名称。在综合后，这些`add_*`module（+操作符）会被打平。  
根据formality提示，在`compile_ultra`前加上`set_verification_priority`后，这些adder就不会被ungroup，也就不会被打平优化，这样就导致了通过该datapath的timing很差，达到-700ps左右。但是，好处也很明显，通过这样综合的网表，是可以pass formal的。  
DC的DesignWare里有多种adder architecture，综合时，DC会根据design约束自动选择合适的adder[^1]。当约束不紧时，DC会选择面积小的逐步进位加法器；当约束紧时，DC会选择更快的加法器，比如优化后的超前进位加法器等。我尝试了对u_tdedgdet不给timing constraint，直接compile，得到的网表可以pass formal；又通过`characterize`把top constraint约束到u_tdedgdet，综合后，得到的网表为inconclusive。从这里也可以看出，DC对adder的选择和优化过狠，导致hard verification。  
既然加了`set_verification_priority`后的网表时序太差，那么能否通过incremental compile来优化timing？  
首先，DC在使用`set_verification_priority`时，是将design/cell 的`verification_priority` attribute 设为`default`,而不是`true`，这一点需要注意。  
另外，我发现DC好像无法remove掉该attribute。如下，我明明已经用`remove_attribute`或`remove_verification_priority`去掉了，而且`get_attribute`也显示没有该属性，但是在ungroup、compile的时候还是会有log显示有该属性。这一点真的是比较奇怪，个人觉得应该是DC的一个bug。  
~~~

dc_shell> get_cells -filter "verification_priority==default" -hierarchical
{**/**/**/add_x_91 **/**/**/add_x_90 **/**/**/add_x_89 **/**/**/add_x_87 **/**/**/add_x_86 **/**/**/add_x_85 **/**/**/add_x_84 **/**/**/add_x_83 **/**/**/add_x_82 ... }

dc_shell> remove_attribute  [get_cells **/**/**/add_x_*] verification_priority
**/**/**/add_x_91 **/**/**/add_x_90 **/**/**/add_x_89 **/**/**/add_x_87 **/**/**/add_x_86 **/**/**/add_x_85 **/**/**/add_x_84 **/**/**/add_x_83 **/**/**/add_x_82 ...
dc_shell> ungroup [get_cells **/**/**/add_x_*]
Information: '**/**/**/add_x_91' will not be ungrouped because of the verification_priority attribute set on it. (OPT-774)
Information: '**/**/**/add_x_90' will not be ungrouped because of the verification_priority attribute set on it. (OPT-774)
Information: '**/**/**/add_x_89' will not be ungrouped because of the verification_priority attribute set on it. (OPT-774)
Information: '**/**/**/add_x_87' will not be ungrouped because of the verification_priority attribute set on it. (OPT-774)
Information: '**/**/**/add_x_86' will not be ungrouped because of the verification_priority attribute set on it. (OPT-774)
Information: '**/**/**/add_x_85' will not be ungrouped because of the verification_priority attribute set on it. (OPT-774)
Information: '**/**/**/add_x_84' will not be ungrouped because of the verification_priority attribute set on it. (OPT-774)
Information: '**/**/**/add_x_83' will not be ungrouped because of the verification_priority attribute set on it. (OPT-774)
Information: '**/**/**/add_x_82' will not be ungrouped because of the verification_priority attribute set on it. (OPT-774)
Information: '**/**/**/add_x_81' will not be ungrouped because of the verification_priority attribute set on it. (OPT-774)
...

dc_shell> remove_verification_priority -all
1
dc_shell> ungroup [get_cells **/**/**/add_x_*]
Information: '**/**/**/add_x_91' will not be ungrouped because of the verification_priority attribute set on it. (OPT-774)
Information: '**/**/**/add_x_90' will not be ungrouped because of the verification_priority attribute set on it. (OPT-774)
Information: '**/**/**/add_x_89' will not be ungrouped because of the verification_priority attribute set on it. (OPT-774)
Information: '**/**/**/add_x_87' will not be ungrouped because of the verification_priority attribute set on it. (OPT-774)
Information: '**/**/**/add_x_86' will not be ungrouped because of the verification_priority attribute set on it. (OPT-774)
Information: '**/**/**/add_x_85' will not be ungrouped because of the verification_priority attribute set on it. (OPT-774)
Information: '**/**/**/add_x_84' will not be ungrouped because of the verification_priority attribute set on it. (OPT-774)
Information: '**/**/**/add_x_83' will not be ungrouped because of the verification_priority attribute set on it. (OPT-774)
Information: '**/**/**/add_x_82' will not be ungrouped because of the verification_priority attribute set on it. (OPT-774)
Information: '**/**/**/add_x_81' will not be ungrouped because of the verification_priority attribute set on it. (OPT-774)
...

dc_shell> get_attribute **/**/**/add_x_91 verification_priority
Warning: Attribute 'verification_priority' does not exist on cell '**/**/**/add_x_91'. (UID-101)

~~~
Anyway，既然不能ungroup，那我就尝试`group_path`,把through这些adder的path都拿出来设一个group，优化后发现还是修不下去...这么看来，好像使用`verification_priority`这条路进入了死胡同...   
我又试了各种alternative strategy，也仅仅把hard verification points从11个减小到10个...   
换更新的DC/FM版本试试，还是没效果...实在是崩溃...   
最后，向前端要了解密的该module的RTL，结果发现该module里居然12位reg累加了20次，20次！！  
~~~

reg     [11:0]  foo00_2d, foo01_2d, foo02_2d, foo03_2d, foo04_2d;
reg     [11:0]  foo10_2d, foo11_2d, foo12_2d, foo13_2d, foo14_2d;
reg     [11:0]  foo20_2d, foo21_2d, foo22_2d, foo23_2d, foo24_2d;
reg     [11:0]  foo30_2d, foo31_2d, foo32_2d, foo33_2d, foo34_2d;
reg     [11:0]  foo40_2d, foo41_2d, foo42_2d, foo43_2d, foo44_2d;
//省略部分...
wire    [15:0]  barsum_2d   =	foo00_2d + foo01_2d + foo02_2d + foo03_2d + foo04_2d +
                                foo10_2d +                                + foo14_2d +
                                foo20_2d +                                + foo24_2d +
                                foo30_2d +                                + foo34_2d +
                                foo40_2d + foo41_2d + foo42_2d + foo43_2d + foo44_2d ;
wire    [16:0]  foosum_2d   =	foo00_2d + foo01_2d + foo02_2d + foo03_2d + foo04_2d +
                                foo10_2d + foo11_2d + foo12_2d + foo13_2d + foo14_2d +
                                foo20_2d + foo21_2d + foo22_2d + foo23_2d + foo24_2d +
                                foo30_2d + foo31_2d + foo32_2d + foo33_2d + foo34_2d +
                                foo40_2d + foo41_2d + foo42_2d + foo43_2d + foo44_2d ;
//省略部分...
reg     [14:0]  bar_3d;
reg     [11:0]  bar1avg4_3d;
reg     [16:0]    foosum_3d;
always@(posedge clk)
  if (en&dvd)
  begin
    bar1avg4_3d <= barsum_2d[15:4];
      foosum_3d <=   foosum_2d ;
  end
~~~
可以发现，上面这段verilog，由于12位reg多次累加，导致了sum的高位无法pass。而且明显foosum_2d可以复用barsum_2d的逻辑，这部分逻辑是可以优化的。这里复杂的RTL累加，是此次hard verification的罪魁祸首。所以说，good RTL coding style是很重要的，涉及datapath的尤其要注意。SolvNet的[Coding Guidelines for Datapath Synthesis](https://solvnet.synopsys.com/retrieve/015771.html)可以好好阅读一下。  
(PS: 文中涉及design相关已做隐藏\*\*)

## Reference
[^1]:[DesignWare Adder & Multiplier Characterization](https://solvnet.synopsys.com/retrieve/018499.html)

