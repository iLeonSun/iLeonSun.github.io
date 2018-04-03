---
title: hierarchical verification
layout: post
section-type: post
comments: true
date: 2018-03-06
category: verification
tags: [formality]
excerpt_separator: <!--more-->
---
IC设计中，到处都有`top-down`和`bottom-up`的思想，在formal verification里也同样存在。Formality默认就是使用`top-down` + `bottom-up`先结合的策略来做形式验证。<!--more-->    
`top-down verification`其实就是flatten verification，把整个design打平，一个logic cone可以跨越多个hierarchy；这样的好处是可以减少logic cone数目，但是缺点也很明显，就是logic cone会比较大。   
`bottom-up verification`就是hierarchical verification，对design从最底层开始验证，底层验证pass后，将其设为black box，再对上层进行验证，依次进行，直至top design；可以看出来，hierarchical verification的logic cone都相对较小，因为即使是对上层deign验证时，下层design会被设为black box。   
简单情况下，Formality的默认行为已经能够很好的处理了。但是当碰到有些inconclusive verification，可能由于logic cone比较大导致，这时使用hierarchical verification可以帮助我们来减小logic cone，简化验证，就可能在较短的时间获得succeeded verification；对于fail verification，也可以通过hierarchical verification来定位到导致failing的root cause。  

## 1.How to perform hierarchical verification
其实很简单，只要定位到sub design就行。`set_top`后top design是不能重复设定的，可以通过`set_reference_design`和`set_implementation_design`来分别指定要进行验证的sub design，类似于ICC/PT里的`current_design`操作。然后依次`match`和`verify`。  
大致脚本如下：  
```
## read netlist/svf/upf..
set_top r:/WORK/TOP
set_top i:/OWRK/TOP
## to subdesign
set_reference_design r:/WORK/Rsubdeign
set_implementation_design i:/WORK/Isubdesign
match
verify
## back to top design
set_reference_design r:/WORK/TOP
set_implementation_design r:/WORK/TOP
#### set subdesign bbox if pass
set_black_box r:/WORK/Rsubdesign
set_black_box i:/WORK/Isubdesign
match
verify
...
```
   
其实实际项目中，由于设计很复杂，直接verify subdesign可能会fail。  
比如，对于一个subdesign，它的某个output port可能floating，那么DC在优化过程可能会将这个pin相关的path优化掉，那么这个output port就会fail。  
如下，这是个商为12bit的除法器，但是我只需要用后四位的，那么RTL里就不会用到高位的8bit，DC在优化时，就会留下floating的output port。由于它是用的div_pipe DesignWare，在reference里这些高位肯定是有逻辑连接的，那么比较时，就会引起fail。
![subdeign floating output](/img/2018-03-06_bbox_output_floating.png)
这种情况下，就需要把这些点设为dont verify point：
```
set_dont_verify_points -type port  $ref/q[4]
set_dont_verify_points -type port  $ref/q[5]
set_dont_verify_points -type port  $ref/q[6]
...
set_dont_verify_points -type port  $impl/q[4]
set_dont_verify_points -type port  $impl/q[5]
set_dont_verify_points -type port  $impl/q[6]
...
```
    
另外，当低层design pass后，如果直接对其设black box，可能也不能保证高层design pass。比如一种常见的情况是，如果subdesign的某个output port由于其前面的约束，其值可能是定值，比如1；但是对于高层design，这个subdesign bbox的output pin要作为logic cone的input，不加额外设置的话，其可以是0/1/X，那么在为0时就会导致高层design fail。  
这种情况下，verify higher design时，除了要对subdesign 设black box，还要对其output pin设`set_constant`。  
如今的设计都很复杂，如果都要人为地像上述那样来发现问题，再对design做额外设置，那是非常费时费力的。  

## 2.Recommended hierarchical verification
Formality提供了一个非常有效的命令：`write_hierarchical_verification_script`来帮我们做这些事情。这个cmd就是强制工具使用hierarchical verification，然后输出对应的脚本，这个过程中，FM会做match/preverify，对design做出`set_dont_verify_points`,`set_user_match`,`set_constant`等额外约束。其output脚本结构如下：
1. define var/proc
2. bottom design
3. higher design
4. top design

当subdesign verification fail时，verify其higher design时，就不会将subdesign bbox，fail subdesign points 会在higher flatten verification。   
`write_hierarchical_verification_script`的`-path`option可以指定某个instance，这会很方便的帮我们来做某些subdesign的verification。但有时候，我们需要对上百个instance做hierarchical verification，你可以foreach循环上百次，或者对top design来write_hier，然后处理文本，抓出需要的instance。我确实碰到这种情况，也倾向于使用后者方法。这里贴上抓取多个sub instance的脚本：
```
#!/bin/bash
########################################
# author: leon
# Date: 2018/01/22 10:44:01
# Version: 1.0
# usage: get_sub_script.sh all_sub_script.tcl sub_list > sub.tcl
########################################

awk '$0~/### Verifying instances/ {exit} {print}' $1
for sub in `cat $2`
do
	awk 'BEGIN {
			FS="\n";
			RS="\n\n"
		}
		$3~/###   Ref:.*'$sub'\// {print}
		$3~/###   Ref:.*'$sub'$/ {print;exit}
	' $1
done
```

   
## 3.One more thing
如果是对inconclusive design做hierarchical verification，有可能即使对最底层的subdesign也仍然是inconclusive；这时，可以利用save的subdesign session来做并行地跑alternate strategies，因为是最底层的subdesign，logic cone要小很多。  
`set_run_alternate_strategies_options`的manpage有多种并行扔job的方法，但是没提到在当前local服务器的处理，其实很简单，如下：
```
set verification_timeout_limit 0
set_run_alternate_strategies_options -max_cores 8 -num_processes 3 -protocol CUSTOM -submit_command "sh"
run_alternate_strategies -session sub_new/fm_subscript_1.tcl.1.fss -strategies "s3 l1 s7"
```

   
## 4.Conclusion
Hierarchical verification可以有效地简化design，减小logic cone，帮助我们发现问题的症结。
