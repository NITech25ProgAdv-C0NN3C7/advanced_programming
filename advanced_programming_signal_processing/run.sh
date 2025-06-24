#!/bin/sh
# imagemagickで何か画像処理をして，/imgprocにかきこみ，テンプレートマッチング
# 最終テストは，直下のforループを次に変更 for image in $1/final/*.ppm; do
for image in $1/test/*.ppm; do
    bname=`basename ${image}`
    name="imgproc/"$bname
    x=0    	#
    echo $name
    # convert "${image}" "${name}"  # 何もしない画像処理
#   convert -blur 2x6 "${image}" "${name}"
    # convert -median 1 "${image}" "${name}"
#   convert -auto-level "${image}" "${name}"
    convert -equalize "${image}" "${name}"
    rotation=0
    echo $bname:
    for template in $1/*.ppm; do
	echo `basename ${template}`
	if [ $x = 0 ]
	then
	    ./matching $name "${template}" $rotation 1.5 cwp 
	    x=1
	else
	    ./matching $name "${template}" $rotation 1.5 wp 
	fi
    done
    echo ""
done
wait
