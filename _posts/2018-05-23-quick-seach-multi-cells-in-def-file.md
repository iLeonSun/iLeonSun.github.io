---
title: quick search for multi cells in def file
layout: post
section-type: post
comments: true
date: 2018-05-23
category: script
tags: python 
excerpt_separator: <!--more-->
---
目前参与一个GPU项目,芯片很大,划分成了100+个block。项目中我需要找到这些block内的某些flatten cell的location信息，这就要求我去def file里找到这些cell。每个block的基本都是大于1million的instance，def file 其实还是挺大的。    
首先把所有这些cell分开到每个block，reused block 里需要uniq一下; 比如，处理后将他们分到n个不同block，每个block又m=f(n)个cell，n个cell name存进dict。对于n个文件，每个里找到m行，如果每次open一个文件，按照顺序依次找到其中一行，然后return，那么时间复杂度会很大，`O(mn)`，这是很浪费时间的。<!--more-->   
现在的问题就是要在同一个file里找到m个cell，优化的解法应该是将所有的m个cell放到一个regexp pattern里，只open file一次，然后read file，从第一行开始，发现一个match就把对应的sub pattern去除，如此递归下去，直到所有sub pattern都被找到，pattern为空，即可return。    
简单代码如下：
```python
def getCellsLocations(refName,cells,defdir='data/PlaceDesign'):
    '''  
    get cells locations who are in same tile
    '''
    ## uniq cells
    cells = set(cells)
    location = {} 
    defFile = defdir+'/'+refName+'/'+refName+'.def.gz'
    logger.info('Looking for cells in def file: '+defFile)
    unitPattern = re.compile('UNITS DISTANCE MICRONS\s+(\d+)')
    p = '|'.join(cells)
    pattern = '\s+-\s+(%s)\s+\w+\s+\+\s+\w+\s+\(\s*(\S+)\s+(\S+)\s*\)' % p
    with gzip.open(defFile,'rb') as f:
        units = '' 
        for line in f.read().split('\n'):
            if units == '':
                if unitPattern.match(line):
                    units = unitPattern.match(line).group(1)
            if p == '':
                logger.info('All cells has been found.')
                return location
            elif re.match(pattern,line):
                m = re.match(pattern,line)
                cell = m.group(1)
                coordX = m.group(2)
                coordY = m.group(3)
                coordX = float(coordX)/float(units)
                coordY = float(coordY)/float(units)
                logger.info('cell %s location in tile: %.4f,%.4f' % (cell,coordX,coordY) )
                location[cell] = [coordX,coordY]
                ## pattern 
                if re.search('\|'+cell+'\|',p):
                    p = re.sub('\|'+cell+'\|','|',p)
                elif re.search('\|'+cell,p):
                    p = re.sub('\|'+cell,'',p)
                elif re.search(cell+'\|',p):
                    p = re.sub(cell+'\|','',p)
                elif re.search(cell,p):
                    # last one
                    p = re.sub(cell,'',p)
                pattern = '\s+-\s+(%s)\s+\w+\s+\+\s+\w+\s+\(\s*(\S+)\s+(\S+)\s*\)' % p
        if p != '':
            logger.error('some cells are not found: %s' % p)

```
如上，主要部分就是先将所有cell通过`或(|)`组成整个pattern `p`, match到就sub，直到p为空 ，需要注意的是`re.sub`时cellpattern前后的`或(|)`操作符。  
类似地，也可以通过这样的方法来得到port location，但是需要注意的是，port 是一组bus时，后缀的`[]`要转义一下，代码如下：
```python
def getPortsLocations(refName,portNames,defdir='../data/PlanSSB'):
    '''  
    get ports locations
    Note:
        the terminal is 0.395 height, 
        and is different in def in top or bottom.
        So the uppper may be in tile if directly use the def location,need plus 0.395
        +-------------------+
        |      ||           |
        |      -- <-here    |
        |                   |
        |                   |
        |      --           |
        |      ||           |
        +-------------------+
                ^--here

    To simplify it, plus 0.4 for all four sides.
    '''
    escaped = [i.replace('[','\[').replace(']','\]') for i in portNames]
    ports = set(escaped)
    location = {} 
    defFile = os.path.join(defdir,refName,'%s.def.gz' %refName)
    logger.info('Looking for ports in def file: %s' % defFile)
    unitPattern = re.compile('UNITS DISTANCE MICRONS\s+(\d+)')
    p = '|'.join(ports)
    pattern = '-\s+(%s)\s+\+\s+NET\s+.+\s+PORT\s+.+\s+FIXED\s+\(\s*(\S+)\s+(\S+)\s*\)' % p
    with gzip.open(defFile,'rb') as f:
        units = ''
        for line in f.read().split(';\n'):
            if units == '':
                if unitPattern.search(line):
                    units = unitPattern.search(line).group(1)
            if p == '':
                logger.info('All ports have been found.')
                return location
            elif re.search(pattern,line,re.DOTALL):
                m = re.search(pattern,line,re.DOTALL)
                port = m.group(1)
                coordX = m.group(2)
                coordY = m.group(3)
                coordX = float(coordX)/float(units)
                coordY = float(coordY)/float(units)
                logger.info('port %s location in tile: %.4f,%.4f' % (port,coordX,coordY))
                # add 0.4 margin
                if abs(coordX) > abs(coordY):
                    # left or right
                    coordX += 0.4 if coordX > 0 else -0.1
                else:
                    # top or bottom
                    coordY += 0.4 if coordY > 0 else -0.1
                location[port] = [coordX,coordY]
                ## pattern
                ### NOTE: 
                ### a[0] in p is a\[0\], show as a\\[0\\] in Python
                ### to match it, use 'a\\\\\\[0\\\\\\]' or r'a\\\[0\\\]'
                escapedPort = port.replace('[',r'\\\[').replace(']',r'\\\]')
                if re.search('\|'+escapedPort+'\|',p):
                    p = re.sub('\|'+escapedPort+'\|','|',p)
                elif re.search('\|'+escapedPort,p):
                    p = re.sub('\|'+escapedPort,'',p)
                elif re.search(escapedPort+'\|',p):
                    p = re.sub(escapedPort+'\|','',p)
                elif re.search(escapedPort,p):
                    # last one
                    p = re.sub(escapedPort,'',p)
                pattern = '-\s+(%s)\s+\+\s+NET\s+.+\s+PORT\s+.+\s+FIXED\s+\(\s*(\S+)\s+(\S+)\s*\)' % p
        if p != '':
            logger.error('some ports are not found: %s' % p)

```
