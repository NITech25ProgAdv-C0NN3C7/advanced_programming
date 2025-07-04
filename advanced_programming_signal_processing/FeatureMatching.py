import cv2
import numpy as np
import sys
import glob
import os

# # OpenCLを有効化（自動で有効になる場合もある）
# cv2.ocl.setUseOpenCL(True)
# assert cv2.ocl.useOpenCL(), "OpenCLが有効化されていません"

# 引数で渡されたパスから画像を読み込む
img = cv2.imread(sys.argv[1], 0)
template = cv2.imread(sys.argv[2], 0)

# キャッシュ計画進行中、breakやrandなども使用？、inlier率が最大のものを使用できれば良さげ
# # .ppmファイルをすべて取得
# img_files = glob.glob(os.path.join(sys.argv[1]))
# template_files = glob.glob(os.path.join(sys.argv[2]))

# # 画像を読み込む
# images = []
# for file in ppm_files:
#     img = cv2.imread(file)
#     if img is not None:
#         images.append(img)
#     else:
#         print(f"読み込み失敗: {file}")

# 画像を大きくする
resize_scale = 4

template_resized = cv2.resize(template, None, fx=resize_scale, fy=resize_scale, interpolation=cv2.INTER_LINEAR)
img_resized = cv2.resize(img, None, fx=resize_scale, fy=resize_scale, interpolation=cv2.INTER_LINEAR)

# 鮮鋭化、効果ないかも
# kernel = np.array([[0, -1, 0], 
#                    [-1, 5, -1], 
#                    [0, -1, 0]])
# template_resized = cv2.filter2D(template_resized, -1, kernel)
# img_resized = cv2.filter2D(img_resized, -1, kernel)

# 特徴点を抽出
orb = cv2.ORB_create(nfeatures=2000)

kp1, des1 = orb.detectAndCompute(template_resized, None)
kp2, des2 = orb.detectAndCompute(img_resized, None)

# マッチング
bf = cv2.BFMatcher(cv2.NORM_HAMMING, crossCheck=True)
matches = bf.match(des1, des2)

# 良いマッチを絞る
matches = sorted(matches, key=lambda x: x.distance)
good_matches = matches[:30]

pts1 = np.float32([kp1[m.queryIdx].pt for m in good_matches])
pts2 = np.float32([kp2[m.trainIdx].pt for m in good_matches])

# RANSACでホモグラフィ行列を推定（もしくは Fundamental Matrix）
H, mask = cv2.findHomography(pts1, pts2, cv2.RANSAC, ransacReprojThreshold=3.0)

# mask は inlier (正しいマッチ) を1, outlier (誤り) を0とする配列
inlier_matches = [m for i, m in enumerate(good_matches) if mask[i]]

if len(good_matches) > 10 and len(inlier_matches) / len(good_matches) > 0.5:
    # src_pts = np.float32([kp1[m.queryIdx].pt for m in good_matches]).reshape(-1,1,2)
    # dst_pts = np.float32([kp2[m.trainIdx].pt for m in good_matches]).reshape(-1,1,2)

    # M, mask = cv2.findHomography(src_pts, dst_pts, cv2.RANSAC, 5.0)
    h, w = template_resized.shape

    pts = np.float32([[0,0],[0,h-1],[w-1,h-1],[w-1,0]]).reshape(-1,1,2)
    dst = cv2.perspectiveTransform(pts, H)

    # print(f'埋め込み画像の座標(四隅): {dst.reshape(-1,2)/resize_scale}')
    corners = dst.reshape(-1,2) / resize_scale

    rotation = 0
    start_idx = 0

    is_swap_x = corners[0, 0] > corners[2, 0]
    is_swap_y = corners[0, 1] > corners[2, 1]

    if is_swap_x:
        if is_swap_y:
            rotation = 180
            start_idx = 2
        else:
            rotation = 90  # CWらしい、なんで？
            start_idx = 1
    elif is_swap_y:
        rotation = 270
        start_idx = 3

    start_x = round(corners[start_idx, 0])
    start_y = round(corners[start_idx, 1])
    size_x = round(corners[(start_idx + 2) % 4, 0]) - start_x
    size_y = round(corners[(start_idx + 2) % 4, 1]) - start_y

    scale = size_x / template.shape[1]

    # 論理xor
    if is_swap_x != is_swap_y:
        scale = size_x / template.shape[0]

    fixed_scale_percent = 100

    if scale < 0.75:
        fixed_scale_percent = 50
    elif scale > 1.5:
        fixed_scale_percent = 200

    # print(f'TRUE {start_x} {start_y} {size_x} {size_y} {rotation}')
    print(f"1 {start_x} {start_y} {fixed_scale_percent} {rotation}")
    # print(template.shape)
else:
    # print("FALSE 0 0 0 0 0")
    print("0 0 0 0 0")


# マッチング結果の描画
# img_matching = cv2.drawMatches(template_resized, kp1, img_resized, kp2, good_matches, None, flags=cv2.DrawMatchesFlags_NOT_DRAW_SINGLE_POINTS)

# cv2.imwrite('MatchingResult.png', result/img_matching)

