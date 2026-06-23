#include "OrbitRings.h"
#include <cmath>

void OrbitRings::setup(int pointsPerRing) {
    n_ = pointsPerRing;
    ring1_.clear();
    ring2_.clear();
    ring1_.setMode(OF_PRIMITIVE_LINE_LOOP);
    ring2_.setMode(OF_PRIMITIVE_LINE_LOOP);
    for (int i = 0; i < n_; ++i) {
        ring1_.addVertex(glm::vec3(0.0f));
        ring2_.addVertex(glm::vec3(0.0f));
    }
}

void OrbitRings::setWaveform(const std::vector<float>& ch1,
                             const std::vector<float>& ch2) {
    const float twoPi = 6.28318530718f;
    auto rebuild = [&](ofVboMesh& ring, const std::vector<float>& src,
                       bool xzPlane) {
        const int n = static_cast<int>(src.size());
        for (int i = 0; i < n_; ++i) {
            const float theta = twoPi * static_cast<float>(i) / n_;
            float s = 0.0f;
            if (n > 0) {
                int idx = static_cast<int>(
                    static_cast<long long>(i) * n / n_);
                if (idx >= n) idx = n - 1;
                s = src[idx];
            }
            const float r = baseRadius_ + amp_ * s;
            const glm::vec3 p = xzPlane
                ? glm::vec3(r * std::cos(theta), 0.0f, r * std::sin(theta))
                : glm::vec3(r * std::cos(theta), r * std::sin(theta), 0.0f);
            ring.setVertex(i, p);
        }
    };
    rebuild(ring1_, ch1, true);
    rebuild(ring2_, ch2, false);
}

void OrbitRings::draw() {
    ofPushStyle();
    ofSetLineWidth(2.0f);
    ofSetColor(80, 200, 255);
    ring1_.draw();
    ofSetColor(255, 140, 80);
    ring2_.draw();
    ofPopStyle();
}
