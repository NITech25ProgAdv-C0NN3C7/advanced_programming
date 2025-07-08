#include <opencv2/opencv.hpp>
#include <opencv2/features2d.hpp>
#include <opencv2/calib3d.hpp>
#include <iostream>
#include <vector>
#include <string>
#include <filesystem>
#include <future>
#include <cmath>
#include <mutex>

namespace fs = std::filesystem;
using namespace cv;
using namespace std;

// グローバル変数
const int RESIZE_SCALE = 4;
Ptr<ORB> orb = ORB::create(5000);
BFMatcher bf(NORM_HAMMING, true);
vector<tuple<string, Mat, vector<KeyPoint>, Mat>> template_datas;
mutex cout_mutex; // for synchronized console output

string get_result(const Mat& template_img, const Mat& H) {
    int h = template_img.rows;
    int w = template_img.cols;

    vector<Point2f> corners = { {0,0}, {0, float(h - 1)}, {float(w - 1), float(h - 1)}, {float(w - 1), 0} };
    vector<Point2f> corners_in_image;

    perspectiveTransform(corners, corners_in_image, H);
    for (auto& pt : corners_in_image) {
        pt.x /= RESIZE_SCALE;
        pt.y /= RESIZE_SCALE;
    }

    bool is_swap_x = corners_in_image[0].x > corners_in_image[2].x;
    bool is_swap_y = corners_in_image[0].y > corners_in_image[2].y;

    int idx = 0;
    int rotation = 0;

    if (is_swap_x) {
        if (is_swap_y) {
            rotation = 180;
            idx = 2;
        } else {
            rotation = 90;
            idx = 1;
        }
    } else if (is_swap_y) {
        rotation = 270;
        idx = 3;
    }

    int pos_x = round(corners_in_image[idx].x);
    int pos_y = round(corners_in_image[idx].y);
    int size_x = round(corners_in_image[(idx + 2) % 4].x) - pos_x;
    int size_y = round(corners_in_image[(idx + 2) % 4].y) - pos_y;

    double scale = size_x / (double(template_img.cols) / RESIZE_SCALE);
    if (is_swap_x != is_swap_y) {
        scale = size_x / (double(template_img.rows) / RESIZE_SCALE);
    }

    int fixed_scale_percent = 100;
    if (scale < 0.75) fixed_scale_percent = 50;
    else if (scale > 1.5) fixed_scale_percent = 200;

    return to_string(pos_x) + " " + to_string(pos_y) + " " +
           to_string(fixed_scale_percent) + " " + to_string(rotation);
}

// 特徴マッチング
string feature_matching(const string& image_path) {
    Mat image = imread(image_path, IMREAD_GRAYSCALE);
    if (image.empty()) return image_path + " ErrorReadingImage";

    resize(image, image, Size(), RESIZE_SCALE, RESIZE_SCALE, INTER_LINEAR);
    vector<KeyPoint> image_kp;
    Mat image_des;
    orb->detectAndCompute(image, noArray(), image_kp, image_des);

    string best_result = "";
    double best_score = 0.0;

    for (const auto& [template_path, template_img, template_kp, template_des] : template_datas) {
        if (image_des.empty() || template_des.empty()) continue;

        vector<DMatch> matches;
        bf.match(template_des, image_des, matches);

        sort(matches.begin(), matches.end(), [](const DMatch& a, const DMatch& b) {
            return a.distance < b.distance;
        });

        vector<DMatch> good_matches(matches.begin(), matches.begin() + min(size_t(30), matches.size()));
        if (good_matches.size() < 4) continue;

        vector<Point2f> src_pts, dst_pts;
        for (const auto& m : good_matches) {
            src_pts.push_back(template_kp[m.queryIdx].pt);
            dst_pts.push_back(image_kp[m.trainIdx].pt);
        }

        Mat mask;
        Mat M = findHomography(src_pts, dst_pts, RANSAC, 3.0, mask);

        if (!M.empty() && mask.rows > 0) {
            int inliers = countNonZero(mask);
            double score = double(inliers) / good_matches.size();

            if (score > 0.5 && score > best_score) {
                best_score = score;
                best_result = template_path + " " + get_result(template_img, M);
            }
        }
    }

    if (!best_result.empty())
        return image_path + " " + best_result;
    else
        return image_path + " None 0 0 0 0";
}

int main(int argc, char* argv[]) {
    if (argc < 3) {
        cerr << "Usage: " << argv[0] << " <image_dir> <template_dir>\n";
        return 1;
    }

    string image_dir = argv[1];
    string template_dir = argv[2];

    // テンプレート画像の読み込み
    for (const auto& entry : fs::directory_iterator(template_dir)) {
        if (entry.is_regular_file()) {
            if (entry.path().extension() == ".ppm") {
                string path = entry.path().string();
                Mat template_img = imread(path, IMREAD_GRAYSCALE);
                if (template_img.empty()) continue;

                resize(template_img, template_img, Size(), RESIZE_SCALE, RESIZE_SCALE, INTER_LINEAR);

                vector<KeyPoint> kp;
                Mat des;
                orb->detectAndCompute(template_img, noArray(), kp, des);

                template_datas.emplace_back(path, template_img, kp, des);
            }
        }
    }

    // 入力画像の読み込み
    vector<string> image_paths;

    for (const auto& entry : fs::directory_iterator(image_dir)) {
        if (entry.is_regular_file()) {
            if (entry.path().extension() == ".ppm") {
                image_paths.push_back(entry.path().string());
            }
        }
    }

    // 並列実行
    vector<future<string>> futures;
    for (const auto& path : image_paths) {
        futures.push_back(async(launch::async, feature_matching, path));
    }

    for (auto& f : futures) {
        string result = f.get();
        lock_guard<mutex> lock(cout_mutex);
        cout << result << endl;
    }

    return 0;
}
