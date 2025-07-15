#include <opencv2/opencv.hpp>
#include <filesystem>
#include <iostream>
#include <string>
#include <vector>
#include <limits>

namespace fs = std::filesystem;
using namespace cv;
using namespace std;

double matchTemplateAt(const Mat& img, const Mat& templ, Point& bestLoc, double& bestScore) {
    Mat result;
    matchTemplate(img, templ, result, TM_CCOEFF_NORMED);
    double minVal, maxVal;
    Point minLoc, maxLoc;
    minMaxLoc(result, &minVal, &maxVal, &minLoc, &maxLoc);
    bestLoc = maxLoc;
    bestScore = maxVal;
    return maxVal;
}

Mat adjustContrast(const Mat& img, double alpha) {
    Mat out;
    img.convertTo(out, -1, alpha, 0);
    return out;
}

Mat addSaltNoise(const Mat& src, int n = 500) {
    Mat dst = src.clone();
    for (int k = 0; k < n; k++) {
        int i = rand() % dst.cols;
        int j = rand() % dst.rows;
        dst.at<Vec3b>(j, i) = (rand() % 2) ? Vec3b(255, 255, 255) : Vec3b(0, 0, 0);
    }
    return dst;
}

int main(int argc, char** argv) {
    if (argc != 3) return 1;

    Mat img = imread(argv[1]);
    string templ_dir = argv[2];

    double bestScore = -1.0;
    string bestName;
    Point bestLoc;
    Size bestSize;
    int bestAngle = 0;

    vector<double> scales = {0.5, 1.0, 2.0};
    vector<int> angles = {0, 90, 180, 270};

    for (const auto& path : fs::directory_iterator(templ_dir)) {
        if (path.path().extension() != ".ppm") continue;
        string name = path.path().stem();
        Mat templ_orig = imread(path.path().string());

        for (double scale : scales) {
            Size newSize(cvRound(templ_orig.cols * scale), cvRound(templ_orig.rows * scale));
            if (newSize.width < 1 || newSize.height < 1) continue;
            Mat scaled;
            resize(templ_orig, scaled, newSize);

            for (int angle : angles) {
                Mat rotated;
                if (angle == 0) rotated = scaled;
                else {
                    Point2f center(scaled.cols/2.0f, scaled.rows/2.0f);
                    Mat rot = getRotationMatrix2D(center, angle, 1.0);
                    warpAffine(scaled, rotated, rot, scaled.size());
                }

                Point loc;
                double score;
                matchTemplateAt(img, rotated, loc, score);

                if (score > bestScore) {
                    bestScore = score;
                    bestLoc = loc;
                    bestName = name;
                    bestSize = rotated.size();
                    bestAngle = angle;
                }
            }
        }
    }

    cout << bestName << " "
         << bestLoc.x << " " << bestLoc.y << " "
         << bestSize.width << " " << bestSize.height << " "
         << bestAngle << " " << bestScore << endl;

    return 0;
}
