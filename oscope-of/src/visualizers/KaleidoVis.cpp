#include "KaleidoVis.h"

namespace oscope {

void KaleidoVis::setup(int w, int h) {
    w_ = w; h_ = h;
}

void KaleidoVis::update(const VisFrame& frame) {
    bass_ = frame.osc.amp("bass");
    lead_ = frame.osc.amp("lead");
    kick_ = frame.osc.amp("kick");
    pad_  = frame.osc.amp("pad");
    phase_ += ofGetLastFrameTime() * (0.4f + frame.osc.bpm() * 0.005f);
}

void KaleidoVis::draw(int x, int y, int w, int h) {
    ofPushStyle();
    ofPushMatrix();
    ofTranslate(x + w * 0.5f, y + h * 0.5f);

    // Single sector (the post-fx kaleido pass mirrors it across N axes).
    ofRotateRad(phase_);

    const float R = std::min(w, h) * 0.5f;
    ofEnableBlendMode(OF_BLENDMODE_ADD);

    // 1. Pulsing colored discs
    ofFill();
    for (int i = 0; i < 6; ++i) {
        float a = phase_ * (0.6f + i * 0.13f) + i * 0.5f;
        float r = R * (0.18f + 0.5f * (0.5f + 0.5f * std::sin(phase_ + i)));
        float dx = std::cos(a) * r;
        float dy = std::sin(a) * r;
        float hue = std::fmod(phase_ * 30.0f + i * 60.0f + bass_ * 90.0f, 360.0f);
        ofColor c = ofColor::fromHsb(hue, 220, 220, 180);
        ofSetColor(c);
        ofDrawCircle(dx, dy, R * 0.06f * (1.0f + lead_ * 1.5f));
    }

    // 2. Lines radiating from origin
    ofNoFill();
    ofSetLineWidth(2);
    for (int i = 0; i < 8; ++i) {
        float a = phase_ * 0.3f + i * 0.78f;
        float len = R * (0.6f + 0.4f * std::sin(phase_ * 1.7f + i));
        float hue = std::fmod(i * 45.0f + phase_ * 50.0f, 360.0f);
        ofSetColor(ofColor::fromHsb(hue, 200, 255, 160));
        ofDrawLine(0, 0, std::cos(a) * len, std::sin(a) * len);
    }

    // 3. Kick triggers a bright dot at the rim
    if (kick_ > 0.05f) {
        ofFill();
        ofSetColor(255, 230, 180, static_cast<int>(kick_ * 255.0f));
        ofDrawCircle(R * 0.7f, 0.0f, R * 0.04f * (1.0f + kick_));
    }

    // 4. Pad → soft glow halo
    if (pad_ > 0.02f) {
        ofFill();
        for (int g = 4; g >= 1; --g) {
            ofSetColor(180, 140, 220, static_cast<int>(pad_ * 60.0f / g));
            ofDrawCircle(0, 0, R * 0.4f * g * 0.6f);
        }
    }

    ofDisableBlendMode();
    ofPopMatrix();
    ofPopStyle();
}

} // namespace oscope
