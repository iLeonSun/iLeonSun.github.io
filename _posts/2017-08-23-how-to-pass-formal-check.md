---
title: How to pass formal check
date: 2017-08-23
layout: post
section-type: post
comments: true
category: tool
tags: [formality,verification]
---

## Formality
>Formality® is an equivalence-checking (EC) solution that uses formal, static techniques to determine if two versions of a design are functionally equivalent.  

Formality是Synopsys家的LEC工具，是IC设计中常用的工具之一。后端设计中，一般要做两次formality check:
1. 综合后，RTL VS synthesis gate-level netlist.
2. PR后，synthesis netlist VS PR netlist.

![formality check in physical design][1]

DC综合时，涉及designware mapping, retiming optimize, regisiter add/removal等复杂的逻辑操作，导致RLT-gate formality check会比较棘手，虽然DC会产生SVF( Setup Verification for Formality),但是由于设计复杂性，仍然会产生各种意想不到的fail/hard verification.
PR中，由于涉及到的逻辑优化较简单，一般不难pass formality;如果涉及复杂优化，如add/spilt multibit bank等复杂逻辑操作，也许需要生成svf来辅助formality check.
>SVF:
 Setup Verification for Formality, 记录优化过程中的各项逻辑操作，比如replace, merge, uniquify, retime, reg_constant等等，是用于辅助formality verification的。DC产生的不可读svf可以在formality内转成可读文本。
 
## RTL VS GATE
如果综合后，RTL-Gate formality fail/inconclusive,该如何debug呢？
Formality debug 可以有logic cone, failing pattern, analyze_point, alternative strategy 等。
### Fail
Formality fail 通常有以下几种情况：
1. miss constraint
    这种情况下，一般容易从pattern里发现。如果failing pattern里某个pin的值都是相同的，比如failing point 的input pin SE 都是1，则很可能是由于做function formality时 scan enable port 没有设为constant value.
2. datapath
    这里的datapath不是指STA里的data/clk path, 而是加减乘除之内的逻辑运算。这些逻辑 运算可以自己rtl实现，也可以直接例化S家的designware。对于同一个逻辑运算，比如3位乘以5位的乘法器，底层实现可能有多种方式。为了实现timing, S家的大部分designware,如div/multi/div_pipe/multi_pipe等都内置retime属性，在compile时会根据design来做retime 优化。前面也说过，retime属于复杂操作，容易引起fail verification.
主要的处理办法有以下几种：

- DC里对整个design 设置`simplified_verification_mode`，其实就是设置下面的参数:
>The tool sets the value for the following  environment  variables  when the  simplified_verification_mode variable is set to true regardless of the value you specify:
>
>compile_ultra_ungroup_dw = false
>
>compile_clock_gating_through_hierarchy = false
>
>hdlin_verification_priority = true

- 在DC里使用`set_verification_priority` 来告诉DC某个cell/design，要verification优先，不要优化地太狠，不要ungroup。但是verification_priority attribute不会传到subdesign.
- 分两步综合，首先对相关design设dont_retime，compile后,再对design 用optimize_register 做Retime 优化。
- 前面的法都是goabl方法，虽然简单，但是个人发现通常效果并不好,这样的话就要具体问题具分析。
利用`analyze_points` 对failing point分析，通常formality会给出fail reason 和recommendtion. Fail reason 通常会是某些相关的svf operation 被formality rejected.常见的有guide_reg_constant,guide_replace，guide_change_name之类。然后可以用`report_svf_operation -command * -status rejected` 来查看具体是为啥这个svf operation 被formality rejected。比如经常出现的是formality找不到某些pin/cell,这时候就要确认原因，是因为name mismatch 还是真的不存在，不存在的情况多为DC默认会把redundant cell/constant register 删除掉，也许它是为了area考虑，结果导致了formality fail。确定起因后，就要在DC 里work-around 来避免这个问题发生。

### Inconclusive 

Inconclusive 一般由于逻辑太复杂，logic cone 太大，导致formality长时间比较后仍然得不出结论。一般解决方法有:  
- 换更新的formality版本，花钱消灾...
- 加大timeout limit: `verification_timeout_limit`, 0 为no limit;
- 设高datapath effort：`verification_datapath_effort_level`；
- 使用alternate strategy：formality内置其它多种不同算法来比较hard verification,需要挨个尝试，可能全部试过多没用，自求多福...
> verification_alternate_strategy specifies that verification uses a nonstandard strategy for solving hard verifications. 
>
> The order of the list indicates which strategy to use first:
>
> none s2 s3 s1 l2 s10 s8 l1 l3 s4 s6 s5 k1 k2 s7 s9
- DC里相关design设置verification优先，降低opt effort；
- DC先compile hard_verification design, 再compile other designs.

## Project Cases
### Case 1
#### 1.1 Problem
综合后，formality fail，有73个failing points，这些points都属于两个module，随便选取一个points:
u_disptop/U_DISPD_LAI053/u_pnlmemctl/u_imgmemctl/u_abc4x4_dec/prl_ari_0__u_div/U_DIV/bdramclk1x_r_REG42_S1
其余failing points的命名也类似，从这些reg的名字可以看出它们都是做了retime优化的（DC retime的默认命名\*\*REG\*\*_S\*).这些reg都是U_DIV module下，而这个U_DIV是例化了一个DW_div_pipe designware.
#### 1.2 Debug
打开logic cone， 如下图,发现failing points是SD/AD, 在Imp里是constant0; 而Ref里它们是从fm_bb出来，fm_bb 是formality black box，bbox 的input被formality认为loginc cone 的endpoint, output 被认为是logic cone的startpoint,因为不知内部逻辑，其output作为logic cone的startpoint时可以为0/1/X。

![logic cone][2]

analyze_points 对这个点分析：
~~~
fm_shell (verify)> analyze_points r:/WORK/wp45/u_disptop/U_DISPD_LAI053/u_pnlmemctl/u_imgmemctl/u_abc4x4_dec/prl_ari_0__u_div/fm_ret_fwmc_1_1_323/u_disptop/U_DISPD_LAI053/u_pnlmemctl/u_imgmemctl/u_abc4x4_dec/prl_ari_0__u_div/U_DIV/bdramclk1x_r_REG42_S1
Found 2 Unmatched Cone Inputs
--------------------------------
Unmatched cone inputs result either from mismatched compare points
or from differences in the logic within the cones. Only unmatched
inputs that are suspected of contributing to verification failures
are included in the report.
The source of the matching or logical differences may be determined
using the schematic, cone and source views.
--------------------------------
r:/WORK/wp45/u_disptop/U_DISPD_LAI053/u_pnlmemctl/u_imgmemctl/u_abc4x4_dec/prl_ari_0__u_div/clk_gate_a_int_reg[1]/latch/\*lat.00\*
    Is globally unmatched affecting 1 compare point(s):
        i:/WORK/wp45/u_disptop/U_DISPD_LAI053/u_pnlmemctl/u_imgmemctl/u_abc4x4_dec/prl_ari_0__u_div/fm_ret_fwmc_1_1_323/u_disptop/U_DISPD_LAI053/u_pnlmemctl/u_imgmemctl/u_abc4x4_dec/prl_ari_0__u_div/U_DIV/bdramclk1x_r_REG42_S1

-----------
r:/WORK/wp45/u_disptop/U_DISPD_LAI053/u_pnlmemctl/u_imgmemctl/u_abc4x4_dec/prl_ari_0__u_div/fm_ret_fwmc_1_1_323/fm_bb/u_disptop/U_DISPD_LAI053/u_pnlmemctl/u_imgmemctl/u_abc4x4_dec/prl_ari_0__u_div/a_int_reg[3][0]
    Matched with pin i:/WORK/wp45/u_disptop/U_DISPD_LAI053/u_pnlmemctl/u_imgmemctl/u_abc4x4_dec/prl_ari_0__u_div/fm_ret_fwmc_1_1_323/fm_bb/u_disptop/U_DISPD_LAI053/u_pnlmemctl/u_imgmemctl/u_abc4x4_dec/prl_ari_0__u_div/a_int_reg[3][0]
    Exists in the ref cone but not in the impl cone for 1 compare point(s):
        i:/WORK/wp45/u_disptop/U_DISPD_LAI053/u_pnlmemctl/u_imgmemctl/u_abc4x4_dec/prl_ari_0__u_div/fm_ret_fwmc_1_1_323/u_disptop/U_DISPD_LAI053/u_pnlmemctl/u_imgmemctl/u_abc4x4_dec/prl_ari_0__u_div/U_DIV/bdramclk1x_r_REG42_S1

-----------
--------------------------------
Found 1 Rejected Guidance Command
--------------------------------
The rejection of some SVF guidance commands will almost invariably
cause verification failures. For more information use:
        report_svf_operation -status rejected -command command_name
--------------------------------
reg_constant
-----------
--------------------------------
****************************************************************************************
Analysis Completed
1
~~~

分析report,首先logic cone 有两个unmatched inputs：一个是gating, 但是发现这个gating并不影响func,而且ref/imp reg的CK 都是r,所以这个gating并不是导致failing points的原因；另一个是fm_bb，这个存在于ref里，也正是由于这个fm_bb的output是1才导致SD/AD pin fail。
接着，有一个guidance cmd 被rejected：guide_reg_constant，这是svf里把reg标为constant 0/1 的操作。联想到imp里SD/AD pin的startpoints 都是constant 0, 所以应该是DC做reg_constant 操作，将failing point 前的reg 标为0，但是这个操作因为某种原因被formality rejected, 从而ref 里引入了fm_bb。那么到底是为何被reject? report_svf_operation report 截取一段如下：

~~~
## SVF Operation 945483 (Line: 8463522) - reg_constant.  Status: rejected
## Operation Id: 945483
guide_reg_constant \
  -design { wp45 } \
  -replaced { svfTrue } \
  { u_moetop/u_imetop/u_imemap/u_imetf2_2p/u_ime_norm3/u_mult_0/mult_x_1/bimeclk_r_REG123_S1 } \
  { 0 } 

Info:  guide_reg_constant 945483 (Line: 8463522) Cannot find master reference cell 'u_moetop/u_imetop/u_imemap/u_imetf2_2p/u_ime_norm3/u_mult_0/mult_x_1/bimeclk_r_REG123_S1'.
~~~

原因就是：**cannot find master reference cell**。居然没有这个cell?那它又是哪来的？查找svf file，发现：

~~~
## Operation Id: 875794
guide_retiming \
  -design { wp45 } \
  -direction { forward } \
  -libCell { FM_FORK } \
  -input { :__tmp__name___1392479 } \
  -output { :u_moetop/u_imetop/u_imemap/u_imetf2_2p/u_ime_norm3/u_mult_0/mult_x_1/bimeclk_r_REG123_S1 } 

## Operation Id: 945483
guide_reg_constant \
  -design { wp45 } \
  -replaced { svfTrue } \
  { u_moetop/u_imetop/u_imemap/u_imetf2_2p/u_ime_norm3/u_mult_0/mult_x_1/bimeclk_r_REG123_S1 } \
  { 0 } 

~~~

这个reg是经过forward retime后命名为此，随后DC觉得它是个constant 0 reg。constant0 reg可能是因为D pin tie 0,也可能是reset pin tie 1 导致的。那么DC是怎么处理这些constant register 的呢？查找DC log,发现如下信息：
~~~
Information: The register 'u_moetop/u_imetop/u_imemap/u_imetf2_2p/u_ime_norm3/u_mult_0/mult_x_1/bimeclk_r_REG123_S1' is a constant and will be removed. (OPT-1206)
Information: The register 'u_moetop/u_imetop/u_imemap/u_imetf2_2p/u_ime_norm2/u_mult_0/mult_x_1/bimeclk_r_REG123_S1' is a constant and will be removed. (OPT-1206)
Information: The register 'u_moetop/u_imetop/u_imemap/u_imetf2_2p/u_ime_norm1/u_mult_0/mult_x_1/bimeclk_r_REG123_S1' is a constant and will be removed. (OPT-1206)
Information: The register 'u_moetop/u_imetop/u_imemap/u_imetf2_2p/u_ime_norm0/u_mult_0/mult_x_1/bimeclk_r_REG123_S1' is a constant and will be removed. (OPT-1206)
~~~
真相大白：**默认情况下，DC会remove constant register, 并在log里给出OPT-1206提示**。至此，终于找到failing root cause,下面就是针对问题找到解决方法了。DC 对constant register 的处理由以下3个变量控制，默认值都是true:
~~~
compile_seqmap_propagate_constants:           Removes cells with a constant on the input.
compile_seqmap_propagate_high_effort:         Removes cells with a constant on the reset.
compile_seqmap_propagate_constants_size_only: Propagates constants through size_only cells.
~~~
其中，`compile_seqmap_propagate_constants_size_only` 是控制是否传递size_only/dont_touch attribute的constant reg 的constant value，而不是要remove size_only/dont_touch reg。
所以，我们在compile前将这些变量设为false,问题应该就可以迎刃而解了吧。尝试之后，万万没想到，failing points居然更多，而且有很多`Required Inputs`。
~~~
--------------------------------
Found 61 Required Inputs
--------------------------------
A required input is one that is designated as required
for all failing patterns for one or more cpoints and fans out 
to more failing than passing points.
This implies that it may be driving downstream logic that is related to
the failure(s)
--------------------------------
~~~
如此看来，这个变量好像不能乱设啊。不清楚为啥不remove const reg，会导致这么严重的问题。之前的debug好像都付诸东流了...   

#### 1.3 Slove
既然这些reg 是例化了的DW_div_pipe内部的，然后经retime命名为此；那么为何FM retime的时候不能找到它了？难道是FM 的retime 与DC的retime有什么不一样了？明明已经读了SVF，FM会根据SVF做retime呀，真是越想越不合理...   
换个更新版本的DC/FM尝试一下吧，结果居然pass了！！！:disappointed_relieved:   
所以，**如果failing points不多，而且都与DesignWare相关，那么请首先尝试更新版本！**

### Case2 
#### 2.1 Problem
综合完，RTL-Gate Formality inconclusive, 有33个points。原来这个module属于一个42bit除以9bit的除法器，每一位quotient的logic cone都很大，formality 很难比较。
~~~

********************************* Verification Results *********************************
Verification INCONCLUSIVE
(Equivalence checking aborted due to complexity)
   ATTENTION: synopsys_auto_setup mode was enabled.
              See Synopsys Auto Setup Summary for details.
   ATTENTION: RTL interpretation messages were produced during link
              of reference design.
              Verification results may disagree with a logic simulator.
-----------------------------------------------------------------------
 Reference design: r:/WORK/***
 Implementation design: i:/WORK/***
 161129 Passing compare points
 33 Aborted compare points
 0 Unverified compare points
~~~
#### 2.2 Debug
前文提到的方法我都一一试过:timeout-limit, datapath-effort, new tool version, set_verification_priority, 10多种alternative strategy 都没用......
难道真的是因为这个42bit/9bit 的除法器太大了，无论如何都无法过formality?
那么仅综合这个除法器能不能过呢？我尝试把这个除法器module摘出来，仅综合这个module，然后对这个module做formal check,奇迹出现了，居然SUCCESSED.
#### 2.3 Solve
最终，通过优先综合除法器design，再综合其它design, 才成功pass formal check.

## Conclusion
RTL-Gate LEC check 是一项很复杂的过程，通常需要在DC/formality里迭代完成，这是非常耗时的，所以formal check 的经验在此格外重要，大牛可能一眼就看出是什么原因，需要在综合时做何种设置；而吾类菜鸟就要慢慢debug,花费大量时间尝试各种可能。文中所述仅为本人在项目中积累的粗浅经验，有错请指正。**不积跬步无以至千里**，不断积累，早日成大牛!

  [1]: /img/2017-08-21_111804.png "formality check in physical design"
  [2]: /img/logic_cone.png "logic cone"
