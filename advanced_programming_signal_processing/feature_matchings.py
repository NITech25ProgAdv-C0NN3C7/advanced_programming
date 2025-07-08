import concurrent.futures
import cv2
import numpy as np
import os
import sys
import glob
import math

# グローバル変数
# 画像の拡大率
RESIZE_SCALE = 4
# 特徴点抽出の準備
orb = cv2.ORB_create(nfeatures=5000)
# マッチングの準備
bf = cv2.BFMatcher(cv2.NORM_HAMMING, crossCheck=True)
# テンプレート画像の情報を保持するリスト
template_datas = []

def get_result(template, H):
    # テンプレート画像のサイズ
    h, w = template.shape

    # テンプレート画像の4隅
    corners = np.float32([[0, 0], [0, h-1], [w-1, h-1], [w-1, 0]]).reshape(-1, 1, 2)

    # Hで変換 → image内での対応位置
    corners_in_image = cv2.perspectiveTransform(corners, H).reshape(-1, 2) / RESIZE_SCALE

    # 左上の点と回転角を計算
    is_swap_x = corners_in_image[0, 0] > corners_in_image[2, 0]
    is_swap_y = corners_in_image[0, 1] > corners_in_image[2, 1]

    idx = 0
    rotation = 0

    if is_swap_x:
        if is_swap_y:
            rotation = 180
            idx = 2
        else:
            rotation = 90  # CWらしい、なんで？
            idx = 1
    elif is_swap_y:
        rotation = 270
        idx = 3

    pos_x = round(corners_in_image[idx, 0])
    pos_y = round(corners_in_image[idx, 1])
    size_x = round(corners_in_image[(idx + 2) % 4, 0]) - pos_x
    size_y = round(corners_in_image[(idx + 2) % 4, 1]) - pos_y

    # 拡大率を計算
    scale = size_x / (template.shape[1] / RESIZE_SCALE)

    if is_swap_x != is_swap_y:
        scale = size_x / (template.shape[0] / RESIZE_SCALE)

    fixed_scale_percent = 100

    if scale < 0.75:
        fixed_scale_percent = 50
    elif scale > 1.5:
        fixed_scale_percent = 200

    return f"{pos_x} {pos_y} {fixed_scale_percent} {rotation}"


def feature_matching(image_path):
    # 画像の読み込み
    image = cv2.imread(image_path, cv2.IMREAD_GRAYSCALE)
    # 画像の拡大
    image = cv2.resize(image, None, fx=RESIZE_SCALE, fy=RESIZE_SCALE, interpolation=cv2.INTER_LINEAR)
    # 特徴抽出
    image_kp, image_des = orb.detectAndCompute(image, None)

    best_result = None
    best_score = 0

    # テンプレート画像についてループ
    for template_path, template, template_kp, template_des in template_datas:

        if image_des is None or template_des is None:
            continue

        # マッチング
        matches = bf.match(template_des, image_des)

        # 良いマッチングを取り出す
        matches = sorted(matches, key=lambda x: x.distance)
        good_matches = matches[:30]

        if len(good_matches) < 4:
            continue

        src_pts = np.float32([template_kp[m.queryIdx].pt for m in good_matches])
        dst_pts = np.float32([image_kp[m.trainIdx].pt for m in good_matches])

        # M, mask = cv2.findHomography(src_pts, dst_pts, cv2.RANSAC, 5.0)
        M, mask = cv2.findHomography(src_pts, dst_pts, cv2.RANSAC, 3.0)

        if mask is not None:
            # inliers = int(mask.sum())
            inlier_matches = [m for i, m in enumerate(good_matches) if mask[i]]
            score = len(inlier_matches) / len(good_matches)

            if score > 0.5 and score > best_score:
                # H, _ = cv2.findHomography(src_pts, dst_pts, cv2.RANSAC)

                best_score = score
                # best_result = f"{template_path} {get_result(template, H)}"
                best_result = f"{template_path} {get_result(template, M)}"

    if best_result is not None:
        return f"{image_path} {best_result}"
    else:
        return f"{image_path} None 0 0 0 0"


# 画像ファイルをすべて取得
image_paths = glob.glob(os.path.join(sys.argv[1]))
template_paths = glob.glob(os.path.join(sys.argv[2]))

# テンプレート画像の処理
for template_path in template_paths:
    # 画像の読み込み
    template = cv2.imread(template_path, cv2.IMREAD_GRAYSCALE)
    # 画像の拡大
    template = cv2.resize(template, None, fx=RESIZE_SCALE, fy=RESIZE_SCALE, interpolation=cv2.INTER_LINEAR)
    # 特徴抽出
    template_kp, template_des = orb.detectAndCompute(template, None)
    # リストに追加
    template_datas.append((template_path, template, template_kp, template_des))

# 並列処理
with concurrent.futures.ThreadPoolExecutor() as executor:
    results = executor.map(feature_matching, image_paths)

# 結果表示
for result in results:
    print(result)
