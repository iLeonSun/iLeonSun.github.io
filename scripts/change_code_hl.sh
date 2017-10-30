#!/bin/bash
# change code block(``` ~~~) in markdown to Lique format
cd ../_posts/
for i in `ls *md`
do
cat $i | awk '/^[`~]{3}/ {
	n++;
	if (n%2) {
		gsub("[`~]{3}","")
		print "{% highlight",$0,"%}"
	} else {
		print "{% endhighlight %}"
	}
}
!/^[`~]{3}/ {print}
' > $i
done
