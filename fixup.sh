file=$1
image=$2
line=$(python -c "print($(cat $file | wc -l)-2)")
img="$(base64 $image -w 0)"
sed -i "${line}i><g style=\"display:none;opacity:0.5\" inkscape:label=\"reference\"><image xlink:href=\"data:image/png;base64,${img}\" style=\"image-rendering:pixelated\"></image></g" $file
