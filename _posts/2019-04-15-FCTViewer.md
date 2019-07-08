---
title: FCTViewer
date: 2019-04-15
layout: post
section-type: post
comments: true
category: script
tags: [python]
excerpt_separator: <!--more-->
---
FCTViewer是笔者最近完成的一个小工具，它的可以用来分析full chip floorplan和full chip timing(flatten STA)。  
<!--more-->
该工具使用python实现，具体工作可以分为以下部分：  
1. 解析lef/def, 得到design tree structure 和 block/macro/fixed std location  
2. 解析timing report, 得到相关timing info  
3. 使用matplotlib实现floorplan及timing path的可视化  
4. 使用pyqt实现gui及其它widget  

## Introduction
下图为FCTViewer的主窗口截图： 

![FCTViewer Guide][1]

主要有以下几部分：
1. 上方：menu bar 和 tool bar  
2. 正中：绘图区  
3. 右上：timing rpt 表格  
4. 右中：timing arc 表格（detail datapath timing report of selected in upper-right table）  
5. 右下：信息区，显示鼠标选择arc/instance的具体信息  

## Features
FCTViewer有以下features:  
1. 绘图区的floorplan上的instance，如果reference name 相同，则颜色相同  
2. 实现键盘热键，F: Fit，Z: zoom in/out  
3. 实现鼠标中键的zoom in/out  
4. 坐标轴刻度在zoom in/out 时动态显示  
5.  动态显示。用户可以鼠标左击绘图区的instance(polygon)或arc(arrow)，被选中物体会被高亮，右下区会显示其具体信息 
6. 当没有读入timing report时，右部区域隐藏，仅有绘图区，鼠标悬停在floorplan上时会悬浮出现鼠标下方block/marco/stdcell 信息（hover annotation） 
7. 当读入timing report时，右侧三栏出现，悬浮显示信息功能关闭，选中物体信息显示于右下栏  
8. 鼠标左击选中右上栏的某一行（对应一条timing path）时，右中timing arc栏动态显示到该path信息  
9. 右中timing arc table为data path信息，可以按ID/Delay排序  
10. 鼠标左击选中timing arc table某一行（row）或某一个单元格（cell）时（对应于某个timing arc），绘图区高亮该arc，并且右下区显示其信息  
11. design的序列化和反序列化，可以将design保存为python pkl文件，下次可直接load，省去解析design的过程  

## Known issue
1. 点击arc/instance高亮时，可能会有肉眼可见的延迟（使用blit原理）。  

[1]: /img/2019-04-15_FCTViewerGuide.png "FCTViewer Guide"
