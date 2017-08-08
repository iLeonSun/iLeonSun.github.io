#!/bin/bash
# change code block(``` ~~~) in markdown to Lique format
cd ../_posts/
sed -i '
	s/^[`~]\{3\}\(.\+\)/{% highlight \1 %}/
	s/^[`~]\{3\}$/{% endhighlight %}/
	' *
