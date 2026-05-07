#include "MeshVis.h"

namespace oscope {

void MeshVis::setup(int w, int h) {
    w_ = w; h_ = h;
    sphereBase_ = ofMesh::icosphere(1.0f, 4);
    sphereDeformed_ = sphereBase_;
    cam_.setPosition(0.0f, 0.0f, 3.5f);
    cam_.lookAt(glm::vec3(0.0f));
    cam_.setNearClip(0.05f);
    cam_.setFarClip(100.0f);
    bandEnergy_.assign(32, 0.0f);
}

void MeshVis::update(const VisFrame& frame) {
    bpm_  = frame.osc.bpm();
    kick_ = frame.osc.amp("kick");
    bass_ = frame.osc.amp("bass");
    lead_ = frame.osc.amp("lead");
    pad_  = frame.osc.amp("pad");

    yaw_   += static_cast<float>(ofGetLastFrameTime()) * (0.18f + bpm_ * 0.0024f);
    pitch_ += static_cast<float>(ofGetLastFrameTime()) * 0.07f;

    if (frame.osc.beatPulse()) pulseScale_ = 1.0f + 0.45f * (0.4f + kick_);
    pulseScale_ += (1.0f - pulseScale_) * 0.18f;

    // Band energy from ch1 (32 buckets, RMS within each)
    const auto& s = frame.ch1;
    if (!s.empty()) {
        const std::size_t N = s.size();
        const std::size_t band = std::max<std::size_t>(1, N / bandEnergy_.size());
        for (std::size_t b = 0; b < bandEnergy_.size(); ++b) {
            float acc = 0.0f;
            for (std::size_t i = 0; i < band && b * band + i < N; ++i) {
                float v = s[b * band + i];
                acc += v * v;
            }
            float rms = std::sqrt(acc / std::max<std::size_t>(1, band));
            bandEnergy_[b] = bandEnergy_[b] * 0.78f + rms * 0.22f;
        }
    } else {
        // Synthetic when scope is silent : drive bands by voice amps
        const float t = ofGetElapsedTimef();
        const float bands[] = {kick_, bass_, lead_, pad_};
        for (std::size_t b = 0; b < bandEnergy_.size(); ++b) {
            float a = bands[b % 4];
            float syn = a * (0.5f + 0.5f * std::sin(t * (2.0f + b * 0.3f) + b));
            bandEnergy_[b] = bandEnergy_[b] * 0.85f + syn * 0.15f;
        }
    }

    // Build deformed sphere
    const auto& base = sphereBase_.getVertices();
    auto& def = sphereDeformed_.getVertices();
    if (def.size() != base.size()) sphereDeformed_ = sphereBase_;
    for (std::size_t i = 0; i < base.size(); ++i) {
        const glm::vec3& v = base[i];
        // Use the vertex position to pick a band (stable hash)
        float pick = std::abs(v.x * 11.7f + v.y * 5.3f + v.z * 2.1f);
        std::size_t b = static_cast<std::size_t>(std::floor(pick * bandEnergy_.size()))
                        % bandEnergy_.size();
        float displace = 1.0f
            + bandEnergy_[b] * 1.6f
            + (frame.osc.beatPulse() ? 0.0f : 0.0f);
        def[i] = v * displace * pulseScale_;
    }
}

void MeshVis::draw(int x, int y, int w, int h) {
    ofPushStyle();
    ofPushMatrix();

    // Restrict camera to this rectangle by translating the whole scene
    // so its center is at (x+w/2, y+h/2). ofCamera uses the global
    // window for its perspective matrix; we draw inside a viewport.
    glEnable(GL_DEPTH_TEST);
    glClear(GL_DEPTH_BUFFER_BIT);

    cam_.begin(ofRectangle(x, y, w, h));

    // Subtle background gradient
    ofDisableDepthTest();
    ofPushStyle();
    ofSetColor(8, 12, 30);
    ofDrawRectangle(-50, -50, 100, 100);
    ofPopStyle();
    ofEnableDepthTest();

    ofPushMatrix();
    ofRotateRad(yaw_,   0, 1, 0);
    ofRotateRad(pitch_, 1, 0, 0);

    // Wireframe back-pass — slightly larger, dim
    ofSetLineWidth(1);
    ofSetColor(60, 90, 160, 200);
    sphereDeformed_.drawWireframe();

    // Solid pass (additive over background)
    ofEnableBlendMode(OF_BLENDMODE_ADD);
    const float baseHue  = std::fmod(yaw_ * 30.0f + bass_ * 80.0f, 360.0f);
    ofSetColor(ofColor::fromHsb(baseHue, 200, 200, 130));
    sphereDeformed_.draw();

    // Inner glow by drawing the wireframe again at smaller scale, brighter
    ofPushMatrix();
    ofScale(0.85f);
    ofSetColor(255, 220, 180, 180);
    sphereBase_.drawWireframe();
    ofPopMatrix();

    ofDisableBlendMode();
    ofPopMatrix();

    cam_.end();

    glDisable(GL_DEPTH_TEST);
    ofPopMatrix();
    ofPopStyle();
}

} // namespace oscope
