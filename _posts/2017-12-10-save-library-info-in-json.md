---
title: save library info into json
layout: post
section-type: post
comments: true
date: 2017-12-10
category: java
tags: 
excerpt_separator: <!--more-->
---
Library(.lib)里一种可读文本格式，它定义了这个逻辑库的特征和所包含的逻辑单元。如下图，它的内容格式必须满足一定的格式，上部分为库的基本特征，包括lib name,operating condition,voltage map,wire load model,timing/power/niose template definitions等; 下部分为该库所包含的所有cell,包括cell的function/timing/power/noise等详细信息。<!--more-->  

![Fig1. sturcture of a logic library](/img/2017-12-10-logic-lib-structrue.png "Fig1. sturcture of a logic library")

Library很重要，前后端都要用到，Synopsys为了提高它家tool处理lib的速度，会将.lib转成二进制的.db文件，DC/ICC/PT都是读.db。  

## 1.我为何要处理这些.lib文件?

我们知道，一个项目中，可能会用到数千个.lib文件，stdcell有不同的track number,channel width/pitch,这些不同的特征cell不能在PR里弄混，比如正常情况下7 track的core里不能放进去9 track和12 track的cell(multi track情况除外);包括memory/ip/io在内的所有的cell的timing都与operation condition有关，同一个signoff corner下，不能混用到不同operation condition的cell。  

一般情况下，foundary提供的stdcell lib的命名比较规范，从lib name就可以看出track number/operaction condition等许多lib信息。但是memory/IP/IO等lib常常是第三方提供的，命名五花八门，常常需要打开.lib来寻找信息。  

因此，我就打算将这些.lib信息全部抽取出来单独保存到json，以后需要查看库基本信息时，只要看该json文件。  
除此以外，我还加入filter json功能，来处理简单的filter操作，比如找出不同operation condition的.lib，这个在后面会提到。

## 2.为何用json?

首先要介绍一下json：
> JSON(JavaScript Object Notation) 是一种轻量级的数据交换格式。 易于人阅读和编写。同时也易于机器解析和生成。 它基于JavaScript Programming Language, Standard ECMA-262 3rd Edition - December 1999的一个子集。 JSON采用完全独立于语言的文本格式，但是也使用了类似于C语言家族的习惯（包括C, C++, C#, Java, JavaScript, Perl, Python等）。 这些特性使JSON成为理想的数据交换语言  

JSON虽然源于JavaScript，但是因为它简单易读的数据格式，已被广泛应用，多种语言都有库支持json的解析和生成。更多信息可以参考[这里](https://www.json.org/)   

每个.lib对应一个object，所以.lib存到一个list里，可以很简单的写到json里，读起来非常方便。  

## 3.为何用java?

这个主要是出于stdcell方面的考虑，因为为了得到stdcell的track number,channel width/pitch，vt info等需要解析其库名，但是各个foundary或者第三方提供的命名规则完全不一样，例如TSMC的命名如tcbn28hpcplusbwp7t35p140ssg0p81v0p9vm40c_ccs，而ARM的命名如sc9mc_cln28hpm_base_svt_c38_tt_typical_max_0p81v_0c，所以无法统一的处理。  

所以为了方便扩展，给这个stdcell信息定义一个interface，不同的foundary parser都来实现这个interface，可以很好的解决问题。遇到新的命名规则，只需要新写个类来实现interface。  

整个package class structure比较简单，大致如下：  

![Fig2. class structure](/img/2017-12-10-package-hier-diagram.png "Fig2. class structure")

目前，vender只扩展了TSMC和ARM，以后会继续扩展。  

由于库里的operation condition命名规则不同会导致混乱，我将其拿出单独一个object Opc，其opc_name field是按照我定的规则得到的新name，我称其为归一化后的opc name，它和.lib里的default opc name可能会不同。  

JSON的序列化和反序列化使用的是Gson,这是google的json库,详情参考[这里](https://sites.google.com/site/gson/gson-user-guide)。  

Filter类是用来过滤一些expression，目前支持`==`,`!=`,`=~`,`!~`操作，匹配是需用正则表达式，而不是简单的glob。另外，加入了对多个表达式通过`&&`和`||`的支持，实例会在后面给出。  

Util类为工具类，里面包括一些public static的method。  

## 3.使用

我生成了runable jar包，使用时直接使用该jar包。只要有两个方式，toJson和FilterJson，如下：

```
$java -jar ~/Liberty/Lib.jar -help
usage:
toJson:
java -jar Lib.jar -libs libsListFile [-output outputFile]
filterJson:
java -jar Lib.jar -json jsonFile -filter filterExpression -outputAttr AttrName -outputFile outputFile
Please refer README for more info
```

### 3.1 save info to json

toJson时，需要提供所有待解析的.lib文件，放在一个文本里，格式如下：  
	`lib_file_path <vender_if_stdcell>`   
`<vender_if_stdcell>`用来解析stdcell相关的信息。  
`-outputFile outputFile`为optional，不指定情况下，默认保存到当前目录的libs.json。  

实例如下：
```bash
$cat libs.list
...some_path.../tcbn28hpcplusbwp7t30p140hvt/lib_ccs/tcbn28hpcplusbwp7t30p140hvtffg0p88v0c_ccs.lib TSMC
...some_path.../tcbn28hpcplusbwp7t30p140hvt/lib_ccs/tcbn28hpcplusbwp7t30p140hvtffg0p88v0p88v0c_ccs.lib TSMC
...some_path.../tcbn28hpcplusbwp7t30p140hvt/lib_ccs/tcbn28hpcplusbwp7t30p140hvtffg0p88v0p88v125c_ccs.lib TSMC
...some_path.../lib_nldm/USB_AFE_BC.lib
...some_path.../lib_nldm/USB_AFE_LT.lib
...some_path.../lib_nldm/USB_AFE_ML.lib
...some_path.../lib_nldm/USB_AFE_TC.lib
...some_path.../lib_nldm/USB_AFE_WC.lib
...some_path.../lib_nldm/USB_AFE_WCL.lib

$java -jar ~/Liberty/Lib.jar -libs libs.list -output libs.json
Total 4372 libs are parsed.

```
我处理了4000+个libs，用时2mins左右，生成的json如下：
```json
[
  {
    "libname": "tcbn28hpcplusbwp7t30p140hvtffg0p88v0c_ccs",
    "libfile": "tcbn28hpcplusbwp7t30p140hvtffg0p88v0c_ccs.lib",
    "dbfile": "tcbn28hpcplusbwp7t30p140hvtffg0p88v0c_ccs.db",
    "libpath": "/ux/V37_ES2/user/sipaas/01_library/0_STD/tcbn28hpcplusbwp7t30p140hvt/lib_ccs/tcbn28hpcplusbwp7t30p140hvtffg0p88v0c_ccs.lib",
    "dbpath": "/ux/V37_ES2/user/sipaas/01_library/0_STD/tcbn28hpcplusbwp7t30p140hvt/db_ccs/tcbn28hpcplusbwp7t30p140hvtffg0p88v0c_ccs.db",
    "orignal_opc_name": "ffg0p88v0c",
    "opc": {
      "process": "ffg",
      "voltage": 0.88,
      "temperture": 0,
      "opc_name": "ffg_0.88_0"
    },
    "v_map": {
      "COREVDD1": "0.88",
      "COREGND1": "0"
    },
    "node": "28hpcplus",
    "track": "7",
    "channel": "30",
    "vt": "hvt",
    "vender": "TSMC"
  },
  {
    "libname": "tcbn28hpcplusbwp7t30p140hvtffg0p88v0p88v0c_ccs",
    "libfile": "tcbn28hpcplusbwp7t30p140hvtffg0p88v0p88v0c_ccs.lib",
    "dbfile": "tcbn28hpcplusbwp7t30p140hvtffg0p88v0p88v0c_ccs.db",
    "libpath": "/ux/V37_ES2/user/sipaas/01_library/0_STD/tcbn28hpcplusbwp7t30p140hvt/lib_ccs/tcbn28hpcplusbwp7t30p140hvtffg0p88v0p88v0c_ccs.lib",
    "dbpath": "/ux/V37_ES2/user/sipaas/01_library/0_STD/tcbn28hpcplusbwp7t30p140hvt/db_ccs/tcbn28hpcplusbwp7t30p140hvtffg0p88v0p88v0c_ccs.db",
    "orignal_opc_name": "ffg0p88v0p88v0c",
    "opc": {
      "process": "ffg",
      "voltage": 0.88,
      "temperture": 0,
      "opc_name": "ffg_0.88_0"
    },
    "v_map": {
      "COREVDD2": "0.88",
      "COREVDD1": "0.88",
      "COREGND1": "0"
    },
    "node": "28hpcplus",
    "track": "7",
    "channel": "30",
    "vt": "hvt",
    "vender": "TSMC"
  },
  {
    "libname": "tcbn28hpcplusbwp7t30p140hvtffg0p88v0p88v125c_ccs",
    "libfile": "tcbn28hpcplusbwp7t30p140hvtffg0p88v0p88v125c_ccs.lib",
    "dbfile": "tcbn28hpcplusbwp7t30p140hvtffg0p88v0p88v125c_ccs.db",
    "libpath": "/ux/V37_ES2/user/sipaas/01_library/0_STD/tcbn28hpcplusbwp7t30p140hvt/lib_ccs/tcbn28hpcplusbwp7t30p140hvtffg0p88v0p88v125c_ccs.lib",
    "dbpath": "/ux/V37_ES2/user/sipaas/01_library/0_STD/tcbn28hpcplusbwp7t30p140hvt/db_ccs/tcbn28hpcplusbwp7t30p140hvtffg0p88v0p88v125c_ccs.db",
    "orignal_opc_name": "ffg0p88v0p88v125c",
    "opc": {
      "process": "ffg",
      "voltage": 0.88,
      "temperture": 125,
      "opc_name": "ffg_0.88_125"
    },
    "v_map": {
      "COREVDD2": "0.88",
      "COREVDD1": "0.88",
      "COREGND1": "0"
    },
    "node": "28hpcplus",
    "track": "7",
    "channel": "30",
    "vt": "hvt",
    "vender": "TSMC"
  },
...省略...
  {
    "libname": "USB_AFE_LAI053_TC",
    "libfile": "USB_AFE_LAI053_TC.lib",
    "dbfile": "USB_AFE_LAI053_TC.db",
    "libpath": "...somepath.../USB_AFE_LAI053/lib_nldm/USB_AFE_LAI053_TC.lib",
    "dbpath": "...somepath.../USB_AFE_LAI053/db_nldm/USB_AFE_LAI053_TC.db",
    "orignal_opc_name": "tt_0.90_25.0",
    "opc": {
      "process": "tt",
      "voltage": 0.9,
      "temperture": 25,
      "opc_name": "tt_0.9_25"
    },
    "v_map": {
      "AVDD18": "1.8",
      "DVDD09": "0.9",
      "DVSS09": "0.0",
      "AVDD3": "3.0",
      "AVSS3": "0.0"
    }
  },
  {
    "libname": "USB_AFE_LAI053_WC",
    "libfile": "USB_AFE_LAI053_WC.lib",
    "dbfile": "USB_AFE_LAI053_WC.db",
    "libpath": "...somepath.../USB_AFE_LAI053/lib_nldm/USB_AFE_LAI053_WC.lib",
    "dbpath": "...somepath.../USB_AFE_LAI053/db_nldm/USB_AFE_LAI053_WC.db",
    "orignal_opc_name": "ss_0.81_125.0",
    "opc": {
      "process": "ss",
      "voltage": 0.81,
      "temperture": 125,
      "opc_name": "ss_0.81_125"
    },
    "v_map": {
      "AVDD18": "1.62",
      "DVDD09": "0.81",
      "DVSS09": "0.0",
      "AVDD3": "2.7",
      "AVSS3": "0.0"
    }
  },
  {
    "libname": "USB_AFE_LAI053_WCL",
    "libfile": "USB_AFE_LAI053_WCL.lib",
    "dbfile": "USB_AFE_LAI053_WCL.db",
    "libpath": "...somepath.../USB_AFE_LAI053/lib_nldm/USB_AFE_LAI053_WCL.lib",
    "dbpath": "...somepath.../USB_AFE_LAI053/db_nldm/USB_AFE_LAI053_WCL.db",
    "orignal_opc_name": "ss_0.81_M40.0",
    "opc": {
      "process": "ss",
      "voltage": 0.81,
      "temperture": -40,
      "opc_name": "ss_0.81_-40"
    },
    "v_map": {
      "AVDD18": "1.62",
      "DVDD09": "0.81",
      "DVSS09": "0.0",
      "AVDD3": "2.7",
      "AVSS3": "0.0"
    }
  }
]

```

### 3.2 filterJson

得到json之后，我们对它处理，得到我们需要的信息，用法如下：  
  `java -jar Lib.jar -json jsonFile -filter filterExpression -outputAttr AttrName -outputFile outputFile`   
`-filter`后是filter expression，为String，所以如果是多个条件过滤的话，要加上引号。  
`-outputAttr`指的是需要输出的lib attribute，比如我们需要ss_0.81_-40下的所有link lib，我们只要dbfile attribute，其它我们并不需要。   
`-outputFile`是将输出重定向到你指定的file。  

实例如下：
```bash
##比如，我们需要ICC里ss_0.81_-40 corner下的link library
##这里用了multi filter，来过滤到lowpower stdcell(假设design为非low power dsign,不需要这些库).
$ java -jar ~/Liberty/Lib.jar -json libs.json -filter "opc_name=~ss.*_0.81_-40 && libfile!~.*\dv.*\dv.*" -outputAttr dbfile -outputFile sslt.list
$ cat sslt.list
tcbn28hpcplusbwp7t30p140hvtssg0p81vm40c_ccs.db 
tcbn28hpcplusbwp7t30p140ssg0p81vm40c_ccs.db 
tcbn28hpcplusbwp7t30p140mbssg0p81vm40c_ccs.db 
tcbn28hpcplusbwp7t30p140opphvtssg0p81vm40c_ccs.db 
tcbn28hpcplusbwp7t30p140oppssg0p81vm40c_ccs.db 
tcbn28hpcplusbwp7t35p140hvtssg0p81vm40c_ccs.db 
tcbn28hpcplusbwp7t35p140ssg0p81vm40c_ccs.db 
tcbn28hpcplusbwp7t35p140mbhvtssg0p81vm40c_ccs.db 
tcbn28hpcplusbwp7t35p140mbssg0p81vm40c_ccs.db 
tcbn28hpcplusbwp7t35p140opphvtssg0p81vm40c_ccs.db 
tcbn28hpcplusbwp7t35p140oppssg0p81vm40c_ccs.db 
tcbn28hpcplusbwp7t40p140hvtssg0p81vm40c_ccs.db 
tcbn28hpcplusbwp7t40p140ssg0p81vm40c_ccs.db 
tcbn28hpcplusbwp7t40p140mbhvtssg0p81vm40c_ccs.db 
tcbn28hpcplusbwp7t40p140mbssg0p81vm40c_ccs.db 
tcbn28hpcplusbwp7t40p140opphvtssg0p81vm40c_ccs.db 
tcbn28hpcplusbwp7t40p140oppssg0p81vm40c_ccs.db 
AADCSMUD64X20_ssg0p81vm40c.db 
ADDXSMUD32X27_ssg0p81vm40c.db 
ADDXSMUD512X24_ssg0p81vm40c.db 
ADDXSMUD64X19_ssg0p81vm40c.db 
AUD2PRF80X64WE_ssg0p81vm40c.db 
...省略...
SAR_ADC_LAI053_wcl_pg.db 
SENSOR_RX_LAI053_WCL.db 
USB_AFE_LAI053_WCL.db 

```

可以看到，不同的命名规则的lib都可以被抓出来。下面我们只要在ICC里利用简单的proc将output file读进去。  

### 3.3 Tcl proc

这里附上我的proc，将文本读进tcl，存在List里。这里我会过滤掉空白行和以`#`开始的注释行：这主要是以防万一，需要人为额外添加内容时，可以加入注释便于阅读。  
```tcl
##其实很简单，大家肯定都会
proc file2list {file_name} {
	set list_tmp ""
	set openfile [open $file_name]
	while {[gets $openfile content] >=0} {
		if {[regexp {^ *#} $content] || [regexp {^ *$} $content] } {continue}
		lappend list_tmp $content
	}
	close $openfile
	return $list_tmp
}

```

## 4.结语
这样我们就可以实现对lib文本的处理，jar包以后会根据需求扩展。
源码在[github](https://github.com/iLeonSun/Liberty)了。
