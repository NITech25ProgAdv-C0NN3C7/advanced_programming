#include <opencv2/opencv.hpp>
#include <iostream>
#include <fstream>
#include <filesystem>
#include <string>
#include <regex>

namespace fs = std::filesystem;

std::string getFileNameOnly(const std::string& filePath) {
    return fs::path(filePath).stem().string();
}

// ワイルドカード（* と ?）を正規表現に変換する関数
std::regex wildcardToRegex(const std::string& wildcard) {
    std::string regexPattern;
    for (char ch : wildcard) {
        switch (ch) {
            case '*': regexPattern += ".*"; break;
            case '?': regexPattern += "."; break;
            case '.': regexPattern += "\\."; break;
            default: regexPattern += ch; break;
        }
    }
    return std::regex(regexPattern, std::regex::icase);
}

int main(int argc, char** argv) {
    if (argc != 3) {
        std::cerr << "使い方: " << argv[0] << " <対象画像> <テンプレートパターン (例: templates/*.png)>" << std::endl;
        return -1;
    }

    std::string targetImagePath = argv[1];
    std::string templatePattern = argv[2];

    // ディレクトリとワイルドカードに分離
    fs::path patternPath(templatePattern);
    std::string dir = patternPath.parent_path().string();
    std::string pattern = patternPath.filename().string();
    std::regex regexPattern = wildcardToRegex(pattern);

    // 対象画像読み込み
    cv::Mat target = cv::imread(targetImagePath, cv::IMREAD_COLOR);
    if (target.empty()) {
        std::cerr << "対象画像を読み込めません: " << targetImagePath << std::endl;
        return -1;
    }

    double bestScore = -1.0;
    cv::Point bestMatchLoc;
    std::string bestTemplateFile;
    cv::Mat bestTempl;

    for (const auto& entry : fs::directory_iterator(dir)) {
        if (!entry.is_regular_file()) continue;

        std::string filename = entry.path().filename().string();
        if (!std::regex_match(filename, regexPattern)) continue;

        std::string templatePath = entry.path().string();
        cv::Mat templ = cv::imread(templatePath, cv::IMREAD_COLOR);
        if (templ.empty() || templ.cols > target.cols || templ.rows > target.rows) continue;

        cv::Mat result;
        result.create(target.rows - templ.rows + 1, target.cols - templ.cols + 1, CV_32FC1);

        cv::matchTemplate(target, templ, result, cv::TM_CCOEFF_NORMED);

        double minVal, maxVal;
        cv::Point minLoc, maxLoc;
        cv::minMaxLoc(result, &minVal, &maxVal, &minLoc, &maxLoc);

        if (maxVal > bestScore) {
            bestScore = maxVal;
            bestMatchLoc = maxLoc;
            bestTemplateFile = templatePath;
            bestTempl = templ;
        }
    }

    std::ofstream outputfile("result/" + getFileNameOnly(targetImagePath) + ".txt");

    if (bestScore >= 0) {
        outputfile << getFileNameOnly(bestTemplateFile) << ' ' << bestMatchLoc.x << ' ' << bestMatchLoc.y << ' ' << bestTempl.cols << ' '  << bestTempl.rows << ' ';
        outputfile << '0' << ' ' << bestScore << '\n';
    } else {
        outputfile << '\n';
    }

    outputfile.close();

    return 0;
}
