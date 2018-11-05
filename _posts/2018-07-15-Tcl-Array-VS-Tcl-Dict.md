---
title: Array VS Dict in Tcl
layout: post
section-type: post
comments: true
date: 2018-07-15
category: script
tags: tcl
excerpt_separator: <!--more-->
---
Tcl8.5开始引入了`dict`,`dict`与`array`类似，都是处理键值对；但它们又有明显的差异。`Tcl Array`虽然译为数组，但它其实不是数组，它存储的是变量；`Tcl dict`可被视为`Tcl list`，它存储的是值。    
>Tcl arrays are collections of variables;     
>Tcl dicts are pure values.

<!--more-->
## 1. Tcl array
数组，是一种最基础的数据结构，是由相同类型的元素（element）的集合所组成的数据结构，分配一块连续的内存来存储。利用元素的索引（index）可以计算出该元素对应的存储地址。一般索引从0开始，一维数组的array[0]表示第一个元素，二维数组的array[0][0]表示第一个元素。所以我们这里说的数组其实是`List`,一般的计算机语言里都会有list的结构，Tcl也不例外。List可以有不同的实现方法，比如java里就有`arraylist`和`linkedlist`(链表结构，存储位置不连续)。   
而Tcl里的`array`其实并不是`数组`，它其实是一种键值对的数据结构(perl里称为hash，python里称为dict，java里称为map)。Tcl array存储的是变量，是一堆变量的集合。  
### Tcl array 写法简洁
Tcl array的读写很简洁，可以直接对arrayName(key)操作。eg:
```
% set arr(a) aaa
aaa
% puts $arr(a)
aaa

```

### Tcl Array 与Tcl List 转化
可以将偶数个元素的`Tcl List`直接通过`array set`转化成`Tcl Array`, `Tcl Array` 可以通过`array get`返回一个key-var的`Tcl List`。
```
% array set arr { a aaa b bbb }
% array get arr
a aaa b bbb
```

### Tcl没有多维array
Tcl array的key是string，其实array不支持二维array，但可以用下面的方法来用，很像二维array。
```
% set arr(x1,y1) 11
11
% set arr(x1,y2) 12
12
% array name arr    
x1,y2 x1,y1
```
如上所示，`arr(x1,y1)`的key是`x1,y1`，Tcl会把`()`内的所有string当作key，甚至可以用下面这样来表示二维array，key值为`x1)(y1`:
```
% array unset arr
% set arr(x1)(y1) 11
11
% set arr(x1)(y2) 12
12
% array name arr
x1)(y1 x1)(y2
```

### Tcl array is unordered
`Tcl array`是无序存储的，这也是其一大劣势。如果要按序取出的话，只能先把key按序存储到list里。
```
% array unset arr
% array set arr {
a 11
c 33
d 44
b 22
}
% array name arr
d a b c
% array unset arr
% array set arr {
a 11
c 33
d 44
b 22
}
% array name arr
d a b c
```

## 2. Tcl Dict
`Tcl Dict`是从8.5版才引入的，是高效的键值对操作方式。和array不同的是，dict存储的是值，其可被视为是`Tcl list`，key有序存储，而且可以嵌套。
### Dict is vaule
dict存储的是值，可以直接`puts $dictName`来得到dict value，array是不可以的。
```
% set adict [dict create a 11 d 44 c 33 b 22]
a 11 d 44 c 33 b 22
% puts $adict
a 11 d 44 c 33 b 22
% array set arr {
a 11
b 22
}
puts $arr
cann't read “arr": variable is a array
```

### Dict is a List
`Tcl Dict`是有偶数个元素的list，每个奇数元素为key，其后的偶数元素为value。   
```
% set alist {a 11 b 22 c 33 d 44}
a 11 b 22 c 33 d 44
% dict get $alist a
11
% dict get $alist b
22
### 奇数项list不能转化成dict
% set olist {a 11 b 22 c}
a 11 b 22 c
% dict get $olist a
missing value to go with ke
```
上面的例子中，定义了一个Tcl list `alist`，随后直接对它dict cmd 操作。   
Tcl Dict可以与Tcl List无损转化，由于dict底层是hash table实现，所以其性能还是与list有区别。
> Internally, Tcl uses a hash table to implement a dictionary, so its performance characteristics are quite different from those of a plain list. To avoid the performance cost of shimmering, use only dict or ˇlistˇ commands to modify a dictionary.     
> The conversion between internal representations of a dictionary and a list is lossless. A round-trip conversion from dict to list and back again yields the original value.

### Dict is ordered
既然dict可以和list相互转化，那dict自然也像list那样是有序的。
```
% set adict [dict create a 11 d 44 c 33 b 22]
a 11 d 44 c 33 b 22
% dict for {k v} $adict {
  puts "$k: $v"
}
a: 11
d: 44
c: 33
b: 22
```

### Dict can be nested
Dict存储的是值，它可以像list in list那样来嵌套使用
```
% set person {
lucy {age 20 sex female}  
jake {age 25 sex male}
}

lucy {age 20 sex female}
jake {age 25 sex male}

% dict get [dict get $person lucy] age
20
```
也可用`dict`cmd来嵌套，如下：
```
% dict set person Lucy age 20
Lucy {age 20}
% dict set person Lucy sex female
Lucy {age 20 sex female}
% dict set person Jake age 25
Lucy {age 20 sex female} Jake {age 25}
% dict set person Jake sex male
Lucy {age 20 sex female} Jake {age 25 sex male}
% dict for {name info} $person {
    puts "This is $name"
    dict with info {
        puts "age: $age"
        puts "sex: $sex"
    }
}
This is Lucy
age: 20
sex: female
This is Jake
age: 25
sex: male
```

`Tcl dict`和`Tcl array`的功能有重叠，我一般情况是优先用`tcl array`，毕竟它的写法更简洁；如果需要按序或者嵌套，就用`tcl dict`。
