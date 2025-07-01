#!/bin/sh
# imagemagickで何か画像処理をして，/imgprocにかきこみ，テンプレートマッチング
# 最終テストは，直下のforループを次に変更 for image in $1/final/*.ppm; do
r="0 90 180 270"
for template in $1/*.ppm; do
	btpl=`basename ${template}`
	for rotation in $r; do
	        tpl="rotated/"$rotation"/"$btpl
		convert -rotate $rotation "${template}" "${tpl}"
	done
done

for image in $1/test/*.ppm; do
	bname=`basename ${image}`
	name="imgproc/"$bname
	x=0    	#
	echo $name
	convert "${image}" "${name}"  # 何もしない画像処理
	#   convert -blur 2x6 "${image}" "${name}"
	# convert -median 1 "${image}" "${name}"
	#   convert -auto-level "${image}" "${name}"
	# convert -equalize "${image}" "${name}"
	echo $bname:
	for template in $1/*.ppm; do
		echo `basename ${template}`
		btpl=`basename ${template}`
		if [ $x = 0 ]
		then
			printf '%s ' $r | xargs -d' ' -I{} -P4 ./matching $name "rotated/{}/${btpl}" {} 1.5 cwp 
			# for rotation in $r; do
			# 	./matching $name "rotated/${rotation}/${btpl}" $rotation 1.5 cwp 
			# done
			x=1
		else
			printf '%s ' $r | xargs -d' ' -I{} -P4 ./matching $name "rotated/{}/${btpl}" {} 1.5 wp 
			# for rotation in $r; do
			# 	./matching $name "rotated/${rotation}/${btpl}" $rotation 1.5 wp 
			# done
		fi
	done
	echo ""
done
wait
