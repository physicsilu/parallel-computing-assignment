#include <iostream>
#include <fstream>
#include <string>
#include <unordered_map>
#include <sstream>
#include <cctype>

bool isElaborateReview(const std::string &text) {
    int count = 0;
    bool inWord = false;
    for (char ch : text) {
        if (std::isspace(ch)) {
            if (inWord) {
                count++;
                inWord = false;
            }
        } else {
            inWord = true;
        }
    }
    if (inWord) count++; 
    return count >= 50;
}

std::string extractJSONField(const std::string &line, const std::string &key) {
    std::string keyPattern = "\"" + key + "\": \"";
    size_t start = line.find(keyPattern);
    if (start == std::string::npos) return "";
    start += keyPattern.length();
    size_t end = line.find("\"", start);
    if (end == std::string::npos) return "";
    return line.substr(start, end - start);
}

int main() {
    std::ifstream infile("Electronics_5.json");
    std::ofstream outfile("elaborate_reviewers.txt");
    std::unordered_map<std::string, int> reviewerCounts;

    std::string line;
    while (std::getline(infile, line)) {
        std::string reviewerID = extractJSONField(line, "reviewerID");
        std::string reviewText = extractJSONField(line, "reviewText");

        if (reviewerID.empty() || reviewText.empty()) continue;

        if (isElaborateReview(reviewText)) {
            reviewerCounts[reviewerID]++;
        }
    }

    long count = 0;
    for (const auto &entry : reviewerCounts) {
        if (entry.second >= 5) {
            outfile << entry.first << "\n";
            count++;
        }
    }

    std::cout << "Total number of reviewers with 5 or more elaborate reviews: " << count << "\n";
    std::cout << "Please look into the elaborate_reviewers.txt file for the list of elaborate reviewers!\n";
    return 0;
}
