#!/bin/sh
# imagemagickで何か画像処理をして，/imgprocにかきこみ，テンプレートマッチング
# 最終テストは，直下のforループを次に変更 for image in $1/final/*.ppm; do
# ↑最終テスト時には下のimages_dirのtestをfinalに変更してください　すべてのlevelについて適用できます
level=$1

images_dir=$level"/test/"
templates_dir=$level"/"

images=$images_dir"*.ppm"
templates=$templates_dir"/*.ppm"

if [ $level = "level1" ]
then
    for image in $images; do
        bname=`basename ${image}`
        name="imgproc/"$bname
        x=0
        echo $name
        convert "${image}" "${name}"  # 何もしない画像処理

        rotation=0
        echo $bname:
        for template in $templates; do
            template_bname=`basename ${template}`
            echo $template_bname

            if [ $x = 0 ]
            then
                ./matching $name $template $rotation 0.5 cpg
                x=1
            else
                ./matching $name $template $rotation 0.5 pg
            fi

        done
        echo ""
    done
    wait

elif [ $level = "level2" ]
then
    for image in $images; do
        bname=`basename ${image}`
        name="imgproc/"$bname
        x=0
        echo $name
        convert "${image}" "${name}"  # 何もしない画像処理

        rotation=0
        echo $bname:
        for template in $templates; do
            template_bname=`basename ${template}`
            echo $template_bname

            if [ $x = 0 ]
            then
                ./matching $name $template $rotation 1.5 cp
                x=1
            else
                ./matching $name $template $rotation 1.5 p
            fi

        done
        echo ""
    done
    wait

elif [ $level = "level3" ]
then
    for image in $images; do
        bname=`basename ${image}`
        name="imgproc/"$bname
        x=0
        echo $name
        convert -equalize "${image}" "${name}"  # コントラスト補正

        rotation=0
        echo $bname:
        for template in $templates; do
            template_bname=`basename ${template}`
            echo $template_bname

            if [ $x = 0 ]
            then
                ./matching $name $template $rotation 1.5 cp
                x=1
            else
                ./matching $name $template $rotation 1.5 p
            fi

        done
        echo ""
    done
    wait

elif [ $level = "level4" ]
then
    # level4の処理
    echo "unimplemented"

elif [ $level = "level5" ] || [ $level = "level7" ]
then
    # コントラスト補正
    for image in $images; do
        convert -equalize $image "imgproc/"`basename $image`
    done
    
    # 特徴マッチング
    feature_matching_results=$(python3 feature_matchings.py "imgproc/"$level"_*.ppm" $templates_dir"*.ppm")

    # 行に対してループ
    echo "$feature_matching_results" | while IFS= read -r line; do
        set -- $line
        processed_image=$1  # 埋め込み後画像は加工済み
        template=$2  # 埋め込み前画像は未加工
        pos_x=$3
        pos_y=$4
        scale_percent=$5
        rotation=$6

        if [ "$template" = "None" ]
        then
            # 見つかっていなければノイズが乗っている、回転は0と断定してOK？
            # すべてのテンプレートについてテンプレートマッチング

            # processed_imageをリセット
            image=$images_dir`basename $processed_image`
            convert $image $processed_image

            x=0

            for template in $templates; do
                if [ $x = 0 ]
                then
                    ./matching $processed_image $template 0 1.5 cp
                    x=1
                else
                    ./matching $processed_image $template 0 1.5 p
                fi
            done
        else
            # 見つかっていればそのテンプレートについてのみテンプレートマッチング

            # processed_imageとprocessed_templateをリセット
            image=$images_dir`basename $processed_image`
            processed_template="imgproc/"`basename $template`
            
            convert $image $processed_image
            convert $template $processed_template

            if [ $scale_percent -ne 100 ]
            then
                convert -resize $scale_percent"%" $processed_template $processed_template
            fi

            if [ $rotation -ne 0 ]
            then
                convert -rotate $rotation $processed_template $processed_template
            fi

            ./matching $processed_image $processed_template $rotation 1.5 cpg $pos_x $pos_y
        fi

        # output_name="result/`basename $template_name`.txt"
        # read template_bname others < $output_name

        # result_template_name=`cat ${result} | awk '{print $1}'`

        # if [ -z $result_template_name ]
        # then
        #     # テンプレートマッチングで見つかっていなければ背景が透過されている
        #     # テンプレートの黒を無視するオプション付ける？多分和真氏が作ってたのでそれを利用？
        # fi
    done

elif [ $level = "level6" ]
then
    r="0 90 180 270"
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
fi