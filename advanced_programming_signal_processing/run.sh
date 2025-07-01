#!/bin/sh
# imagemagickで何か画像処理をして，/imgprocにかきこみ，テンプレートマッチング
# 最終テストは，直下のforループを次に変更 for image in $1/final/*.ppm; do
level=$1

# images=$level/test/*.ppm
# templates=$level/*.ppm

# # ノイズどうするか

# python3 FeatureMatching.py $images $templates > FeatureMatchingResult.txt
# while read line
# do
#     # コマンド
# done < FeatureMatchingResult.txt

for image in $level/test/*.ppm; do
    bname=`basename ${image}`
    name="imgproc/"$bname
    x=0    	#
    echo $name
    convert "${image}" "${name}"  # 何もしない画像処理
#   convert -blur 2x6 "${image}" "${name}"
    # convert -median 1 "${image}" "${name}"
#   convert -auto-level "${image}" "${name}"
    # 常にコントラスト補正したほうが精度高そう
    convert -equalize "${image}" "${name}"

    # 試しにノイズ除去もしてみる -> ダメでした
    removed_noise="imgproc/removed_noise.ppm"
    convert -median 2 $name $removed_noise

    rotation=0
    echo $bname:
    for template in $level/*.ppm; do
        template_bname=`basename ${template}`
        echo $template_bname

        template_name="imgproc/"$template_bname

        convert -equalize $template $template_name  # こっちもコントラスト補正

        # json=$(python3 FeatureMatching.py "$name" "$template")

        # is_found=$(echo "$json" | jq -r '.is_found')

        # jq使えなかった
        output=$(python3 FeatureMatching.py $name $template_name)

        echo $output

        set -- $output
        is_found=$1
        start_x=$2
        start_y=$3
        scale_percent=$4
        rotation=$5

        if [ $is_found -eq 1 ]
        then
            

            if [ $scale_percent -ne 100 ]
            then
                convert -resize $scale_percent"%" $template_name $template_name
            fi

            if [ $x = 0 ]
            then
                ./matching $name $template_name $rotation 100 cwpg
                x=1
            else
                ./matching $name $template_name $rotation 100 wpg
            fi
        fi

        # 古いやつ
        # template_name="imgproc/"$template_bname

        # convert $template $template_name  # 何もしない画像処理

        # for scale in "50%" "100%" "200%"; do
        #     if [ $scale != "100%" ]
        #     then
        #         convert -resize $scale $template_name $template_name
        #     fi

        #     if [ $x = 0 ]
        #     then
        #         ./matching $name $template_name $rotation 1.5 cwp
        #         x=1
        #     else
        #         ./matching $name $template_name $rotation 1.5 wp
        #     fi
        # done

    done
    echo ""
done
wait
