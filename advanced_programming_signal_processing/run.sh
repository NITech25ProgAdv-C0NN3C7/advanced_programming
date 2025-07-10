#!/bin/sh
# imagemagickで何か画像処理をして，/imgprocにかきこみ，テンプレートマッチング
# 最終テストは，直下のforループを次に変更 for image in $1/final/*.ppm; do
# ↑最終テスト時には下のimages_dirのtestをfinalに変更してください　すべてのlevelについて適用できます
set -e

level=$1

mkdir -p imgproc result

images_dir=$level"/test/"
templates_dir=$level"/"

imgproc_dir="imgproc/"

images=$images_dir"*.ppm"
templates=$templates_dir"/*.ppm"

processed_images="$imgproc_dir""$level""_*.ppm"

# バックグラウンドで並列に実行するための関数
run_single_image() {
    image=$1
    templates=$2  # "$templates"のように、ワイルドカードを用いて表現されたパスをダブルクォーテーションで囲って渡してください
    rotation=$3
    threshold=$4
    option=$5  # x=0時のcオプションは自動で付加されます c以外のオプションを渡してください

    x=0

    for template in $templates; do
        if [ $x = 0 ]
        then
            ./matching $image $template $rotation $threshold c"$option"
            x=1
        else
            ./matching $image $template $rotation $threshold "$option"
        fi
    done
}

# バックグラウンドで並列に実行するための関数（level6）
run_single_image6() {
	echo `basename ${1}`
	btpl=`basename ${1}`
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
}

case $level in
	level1)
		printf '%s ' $images | xargs -d' ' -I{} -P 20 sh run_single_image.sh {} "$templates" 0 0.5 pg
		;;
	level2)
		printf '%s ' $images | xargs -d' ' -I{} -P 20 sh run_single_image.sh {} "$templates" 0 1.5 p
		;;
	level3)
		for image in $images;
		do
			# コントラスト補正
			processed_image=$imgproc_dir`basename "$image"`
			convert -equalize "$image" "$processed_image"

			# run_single_image $processed_image "$templates" 0 1.5 p &
		done
		printf '%s ' $processed_images | xargs -d' ' -I{} -P 20 sh run_single_image.sh {} "$templates" 0 1.5 p
		;;
	level4)
		printf '%s ' $images | xargs -d' ' -I{} -P 20 sh run_single_image.sh {} "$templates" 0 0.5 pb 
		;;
	level[57])
		# 特徴マッチング
		# feature_matching_results=$(python3 feature_matchings.py $images_dir"*.ppm" $templates_dir"*.ppm")
		feature_matching_results=$(./feature_matchings "$images_dir" "$templates_dir")
		
		# 結果をファイルに入れないと並列処理のwaitがうまくいかない
		feature_matching_results_file="result/feature_matching_results.txt"
		echo "$feature_matching_results" > "$feature_matching_results_file"
		
		# 行に対してループ
		# echo "$feature_matching_results" | while IFS= read -r line; do
		while IFS= read -r line; do
			
			set -- $line
			image=$1
			template=$2
			pos_x=$3
			pos_y=$4
			scale_percent=$5
			rotation=$6
			
			# image=$images_dir`basename $processed_image`
			processed_image="$imgproc_dir"`basename $image`
			
			if [ "$template" = "None" ]
			then
				# 見つかっていなければノイズが乗っている、回転は0と断定してOK？
				# すべてのテンプレートについてテンプレートマッチング
				sh run_single_image.sh "$image" "$templates" 0 1.5 p &
			else
				# 見つかっていればそのテンプレートについてのみテンプレートマッチング
				# テンプレート画像を加工
				processed_template="$imgproc_dir"`basename "$template"`
				
				# 何もしない
				convert "$template" "$processed_template"
				
				# 必要に応じて拡大縮小
				if [ $scale_percent -ne 100 ]
				then
					convert -resize $scale_percent"%" $processed_template $processed_template
				fi
				
				# 必要に応じて回転
				if [ $rotation -ne 0 ]
				then
					convert -rotate $rotation $processed_template $processed_template
				fi
				
				# テンプレートマッチング
				./matching $image $processed_template $rotation 1.5 cpg $pos_x $pos_y &
			fi
			
		done < $feature_matching_results_file
		wait

		results="result/"$level"_*.txt"

		for result in $results; do
			# result_template_name=`cat ${result} | awk '{print $1}'`
			result_contents=`cat $result`
			
			if [ -z "$result_contents" ];
			then
				result_image=$images_dir`basename $result .txt`".ppm"

				while IFS= read -r line; do
					set -- $line
					image=$1
					template=$2
					pos_x=$3
					pos_y=$4
					scale_percent=$5
					rotation=$6

					if [ $image = $result_image ]
					then
						# テンプレートマッチングで見つかっていなければ背景が透過されている
						./matching $image $template $rotation 0.1 pb &
					fi
					
				done < $feature_matching_results_file
			fi
		done
		;;
	level6)
		r="0 90 180 270"

		# テンプレ回転ディレクトリの作成
		mkdir -p rotated
		cd rotated
		mkdir -p $r
		cd ..
		
		for template in $templates; do
			btpl=`basename ${template}`
			for rotation in $r; do
				tpl="rotated/"$rotation"/"$btpl
				convert -rotate $rotation "${template}" "${tpl}"
			done
		done
		
		for image in $images; do
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
			for template in $templates; do
				run_single_image6 $template &
			done
			echo ""
		done
		;;
	*)
		echo "Unexpected level '${level}'" >&2
		;;
esac

wait
