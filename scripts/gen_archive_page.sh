#!/usr/bin/bash
years=`awk -F "-| " '/^date:/ {print $2;next}' ../_posts/*md | sort -u`
categories=`awk '/^category:/ {print $2;next}' ../_posts/*md | sort -u`
tags=`awk -F '[\\\[\\\], ]+' '/^tags:/ {for (i=2;i<NF;i++) print $i}' ../_posts/*md | sort -u`
#echo $years
#echo $categories
#echo $tags
##
for year in $years
do
	if [ -e ../_archive/year/$year.md ] 
	then 
		continue
	fi
	echo "--Adding year/$year archive"
cat >../_archive/year/$year.md << EOF
---
layout: year
year: $year
permalink: /year/$year
---
EOF
done

for category in $categories
do
	if [ -e ../_archive/category/$category.md ] 
	then 
		continue
	fi
	echo "--Adding category/$category archive"
cat >../_archive/category/$category.md << EOF
---
layout: category
category: $category
permalink: /category/$category
---
EOF
done

for tag in $tags
do
	if [ -e ../_archive/tag/$tag.md ] 
	then 
		continue
	fi
	echo "--Adding tag/$tag archive"
cat >../_archive/tag/$tag.md << EOF
---
layout: tag
tag: $tag
permalink: /tag/$tag
---
EOF
done
