#!/bin/sh
# バックグラウンドで並列に実行するための関数
image=$1
templates=$2	# "$templates"のように、ワイルドカードを用いて表現されたパスをダブルクォーテーションで囲って渡してください
rotation=$3
threshold=$4
option=$5	# x=0時のcオプションは自動で付加されます c以外のオプションを渡してください

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
