#include "ModelVis.h"

#include <cmath>

namespace oscope {

void ModelVis::setup(int w, int h) {
    w_ = w; h_ = h;
    mesh_.load(plyPath_);
    if (mesh_.getNumVertices() == 0) {
        ofLogError("ModelVis") << "load failed : " << plyPath_;
        return;
    }
    // Auto-fit : trouve bounding box, normalise pour tenir dans [-2..2]
    if (mesh_.getNumVertices() > 0) {
        auto& v = mesh_.getVertices();
        ofVec3f mn = v[0], mx = v[0];
        for (const auto& p : v) {
            mn.x = std::min(mn.x, p.x); mx.x = std::max(mx.x, p.x);
            mn.y = std::min(mn.y, p.y); mx.y = std::max(mx.y, p.y);
            mn.z = std::min(mn.z, p.z); mx.z = std::max(mx.z, p.z);
        }
        meshCenter_ = (mn + mx) * 0.5f;
        const float ex = std::max(mx.x - mn.x,
                          std::max(mx.y - mn.y, mx.z - mn.z));
        autoScale_ = (ex > 0.001f) ? (4.0f / ex) : 1.0f;
        // Si la mesh n'a pas de normales, on les génère
        if (!mesh_.hasNormals()) {
            mesh_.flatNormals();
        }
    }
    camera_.setNearClip(0.1f);
    camera_.setFarClip(40.0f);
    light_.setPointLight();
    light_.setDiffuseColor(ofFloatColor(1.0f, 0.85f, 0.6f));
    light_.setSpecularColor(ofFloatColor(1.0f));
}

void ModelVis::update(const VisFrame& frame) {
    t_      += static_cast<float>(ofGetLastFrameTime());
    bass_    = frame.bands.bass;
    mid_     = frame.bands.mid;
    treble_  = frame.bands.treble;
    kick_    = frame.bands.kick;
    bpm_     = frame.osc.bpm();

    const float orbitR = 7.0f - kick_ * 1.5f;
    const float orbitA = t_ * (0.10f + bpm_ * 0.0008f);
    camera_.setPosition(std::cos(orbitA) * orbitR,
                        std::sin(t_ * 0.18f) * 2.5f,
                        std::sin(orbitA) * orbitR);
    camera_.lookAt(ofVec3f(0, 0, 0));

    light_.setPosition(std::sin(t_ * 0.7f) * 5.0f,
                       3.0f + treble_ * 3.0f,
                       std::cos(t_ * 0.9f) * 5.0f);
    light_.setDiffuseColor(ofFloatColor(
        0.5f + 0.5f * mid_,
        0.4f + 0.6f * treble_,
        0.7f + 0.3f * bass_));
}

void ModelVis::draw(int x, int y, int w, int h) {
    if (mesh_.getNumVertices() == 0) {
        ofPushStyle();
        ofSetColor(50);
        ofDrawRectangle(x, y, w, h);
        ofSetColor(255, 80, 80);
        ofDrawBitmapString("model missing : " + plyPath_, x + 12, y + 24);
        ofPopStyle();
        return;
    }
    ofPushStyle();
    ofPushMatrix();
    ofViewport(x, y, w, h, false);
    ofEnableDepthTest();
    ofEnableLighting();
    light_.enable();
    camera_.begin(ofRectangle(0, 0, w, h));

    ofPushMatrix();
    // Rotation continue + scale audio + recentrage
    ofRotateRad(t_ * 0.5f, 1, 0, 0);
    ofRotateRad(t_ * 0.7f, 0, 1, 0);
    const float s = autoScale_ * userScale_ * (1.0f + bass_ * 0.15f);
    ofScale(s, s, s);
    ofTranslate(-meshCenter_.x, -meshCenter_.y, -meshCenter_.z);

    // Couleur cycle hue
    ofColor col;
    col.setHsb(static_cast<int>(std::fmod(t_ * 30.0f, 255.0f)),
               180,
               180 + static_cast<int>(75.0f * (mid_ + treble_) * 0.5f));
    material_.setDiffuseColor(col);
    material_.setSpecularColor(ofFloatColor(1.0f, 0.95f, 0.85f));
    material_.setShininess(48.0f);
    material_.begin();
    mesh_.draw();
    material_.end();

    // Wireframe par-dessus pour le côté demoscene
    ofSetColor(255, 230, 180, 120);
    mesh_.drawWireframe();

    ofPopMatrix();

    camera_.end();
    light_.disable();
    ofDisableLighting();
    ofDisableDepthTest();
    ofViewport(0, 0, ofGetWidth(), ofGetHeight(), false);
    ofPopMatrix();
    ofPopStyle();
}

} // namespace oscope
