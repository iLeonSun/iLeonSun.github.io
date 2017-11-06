---
title: understanding SPEF
layout: post
section-type: post
comments: true
date: 2017-11-06
category: STA
tags: [SPEF]
excerpt_separator: <!-- more -->
---
SPEF(Standard Parasitic Exchange Format)是一种IEEE标准，包含着线上的寄生电阻、电容、电感等信息。SPEF是ASCII格式，可读的。PR后，要抽取spef，在STA工具里反标net上的RC，再配合db里std cell的RC，通过完整的RC才能计算得到准确的timing。  
反标RC过程中，经常会出现warning、error等信息，这时我们就需要debug spef。所以，我们有必要了解SPEF的语法格式。<!-- more -->   
SPEF file通常包括四个部分：
1. Header section
2. Name map section
3. Ports section
4. Main parasitic description section

SPEF的keyword以\*开头，如：`*NAME_MAP`,`*D_NET`;注释以`//`开头。

## 1.Header section
Header section 一般14行，包含spef version, design name, tool version, naming style, units等。   
实例：  
```
*SPEF "IEEE 1481-1999"
*DESIGN "mydesign"
*DATE "Sat Nov  4 17:13:47 2017"
*VENDOR "Synopsys Inc."
*PROGRAM "StarRC"
*VERSION "M-2017.06-SP2"
*DESIGN_FLOW "PIN_CAP NONE" "NAME_SCOPE LOCAL"
*DIVIDER /
*DELIMITER :
*BUS_DELIMITER []
*T_UNIT 1.0 NS
*C_UNIT 1.0 FF
*R_UNIT 1.0 OHM
*L_UNIT 1.0 HENRY
```

## 2.Name map section
由于cell/net name会很长，并且同一个net/cell会重复多次出现，为了减小文件大小，会将name映射成数字，在文件后面该数字就表示该name。  
实例：
```
*2608468 xtggpio[2]
*2608469 xtggpio[1]
*2608470 xtggpio[0]
*2608471 xtgclk
*2608472 xflash
*2608473 xmshutter
*2608474 xhd
//...
*2621011 u_corei053/u_audtop/U_AUDD_LAI053/u_audgain/u_auddateng0/engaccval_reg_11___engaccval_reg_10___engaccval_reg_9___engaccval_reg_8___engaccval_reg_7___engaccval_reg_6___engaccval_reg_5___engaccval_reg_4_
*2621012 u_corei053/u_audtop/U_AUDD_LAI053/u_audgain/u_auddateng0/engaccval_reg_19___engaccval_reg_18___engaccval_reg_17___engaccval_reg_16___engaccval_reg_15___engaccval_reg_14___engaccval_reg_13___engaccval_reg_12_
*2621013 u_corei053/u_audtop/U_AUDD_LAI053/u_audgain/u_auddateng0/engaccval_reg_27___engaccval_reg_26___engaccval_reg_25___engaccval_reg_24___engaccval_reg_23___engaccval_reg_22___engaccval_reg_21___engaccval_reg_20_
```

## 3.Ports session
Port session包含design所有顶层端口，其格式为：  
`port_name direction`   
`port_name`是上面已经name_mapping后的数字格式;   
`direction`可以为`I`,`O`,`B`,分别对应input,output,inout。  
实例：
```
*PORTS

*1169423 I
*1169424 I
*1169425 I
*1169426 O
*1169427 O
*1169428 O
*1169429 O
*1169430 O
*2608614 B
*2608615 B
*2608616 B
```

## 4.Main parasitic description section
这个部分就是整个design所有net的寄生RCL信息了，每条net通常以`*D_NET`和`*END`关键字分开。  
D_NET表示distributed net，除此外，还有3种很少用：  
R_NET表示reduced nets;   
D_PNET表示distributed physical net;  
R_PNET表示reduced physical nets.  
每条net包含`*CONN`,`*CAP`,`*RES`部分，格式如下：    
```
*D_NET net_name total_cap
*CONN
//connection information
*CAP
//detailed cap information
*RES
//detailed res information
*END
```

### 4.1 connection section
`*CONN`部分列出该条net所有的pin，此外，还会把该net的内部节点，其格式如下：  
`conn_type pin_name [direction] [driving info] *C xy_coordinate`   
`conn_type`有三种：`*I`,`*P`,`*N`，分别指：  
`*I`: internal connection，连到logic instant pin，后面跟instant pin name;   
`*P`: external connection，连到port，后面跟port name;  
`*N`: internal node，工具将net断开的内部节点，后面跟net node。  
conn_type为`I`或`P`时，需指定pin/port direction，value可以为`I`和`O`，分别指input,output。  
对output pin可以指定其driver cell,格式为`*D ref_name`。  
`*C xy_coordinate`表示该pin/port/node的坐标。  
实例：  
```
*CONN
*I *2614346:I I *C 1109.1300 1841.2300
*I *2614347:ZN O *D INVD2BWP7T40P140HVT *C 1208.3900 1760.8700
*N *4816:2 *C 1109.1300 1841.2300
*N *4816:3 *C 1208.3900 1760.8700
*N *4816:4 *C 1208.3900 1760.8700
*N *4816:5 *C 1208.3400 1760.8800

// 连到port
*CONN
*P *2608554 B *C 82.4600 929.0250
*I *4826447:PAD B *D PRWHSWCDGSD_H *C 82.4600 929.0250
```

### 4.2 capacitor section
`*CAP`部分列出该条net的所有cap，包括与GND之间的cap和与相邻net之间的coupled cap，格式分别为：   
`num net_node cap_value`   
`num net_node another_net_node coupled_cap_value`    
实例：  
```
*CAP
1 *2614346:I *3739625:I 1.89347 //coupled cap
2 *2614346:I *1321176:4 1.07336
3 *4816:5 *1890744:7 0.277137
4 *4816:5 *4216046:D 0.0689194
5 *4816:5 *1891199:15 1.56794
6 *2614346:I *4465732:I 0.425209
7 *2614346:I *2160917:2 0.016052
8 *2614346:I *4469463:B 0.0161593
9 *2614346:I *2160919:3 0.00672438
10 *2614346:I *2161659:3 0.0140435
11 *2614346:I *4470463:A 0.00825583
12 *2614346:I *4474070:B 0.0595718
13 *2614346:I *2166777:7 0.0540128
14 *2614346:I *2169344:2 0.217477
15 *2614346:I *2183021:6 1.00391
16 *2614346:I 5.95695 //to GND
17 *4816:5 9.14826 //to GND
```

### 4.3 resistance section
`*RES`部分列出该条net上所有金属块的电阻。实例如下：   
```
*RES
1 *2614346:I *4816:2 0.001
2 *2614346:I *4816:5 667.144
3 *2614347:ZN *4816:3 6.25715
4 *2614347:ZN *4816:4 0.001
5 *4816:3 *4816:5 0.133914
```
