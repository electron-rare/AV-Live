#include "PolarVis.h"

namespace oscope {

void PolarVis::setup(int w, int h) {
    w_ = w;
    h_ = h;
    trace1_.resize(720, 0.0f);
    trace2_.resize(720, 0.0f);
}

void PolarVis::update(const VisFrame& frame) {
    bpm_  = frame.osc.bpm();
    kick_ = frame.osc.amp("kick");
    bass_ = frame.osc.amp("bass");
    lead_ = frame.osc.amp("lead");

    // Roll the trace forward, push new samples
    const std::size_t step = std::max<std::size_t>(1, trace1_.size() / 90);
    const auto& s1 = frame.ch1;
    const auto& s2 = frame.ch2;
    if (!s1.empty()) {
        for (std::size_t i = 0; i < step; ++i) {
            trace1_.erase(trace1_.begin());
            trace2_.erase(trace2_.begin());
            trace1_.push_back(s1[i % s1.size()]);
            trace2_.push_back(s2[i % s2.size()]);
        }
    } else {
        // Synthetic when scope is silent
        const float t = ofGetElapsedTimef();
        for (std::size_t i = 0; i < step; ++i) {
            trace1_.erase(trace1_.begin());
            trace2_.erase(trace2_.begin());
            float a = std::sin(t * 4.0f + i * 0.1f) * (0.3f + lead_);
            float b = std::cos(t * 3.5f + i * 0.13f) * (0.3f + bass_);
            trace1_.push_back(a);
            trace2_.push_back(b);
        }
    }

    rotation_ += ofGetLastFrameTime() * (0.15f + bpm_ * 0.0015f);

    if (frame.osc.beatPulse()) {
        shockR_ = 0.0f;
        shockA_ = 1.0f + kick_;
    }
    shockR_ += ofGetLastFrameTime() * 800.0f;
    shockA_ *= 0.93f;
}

void PolarVis::draw(int x, int y, int w, int h) {
    ofPushStyle();
    ofPushMatrix();
    ofTranslate(x + w * 0.5f, y + h * 0.5f);
    ofRotateRad(rotation_);

    const float radius = std::min(w, h) * 0.4f;

    // Background concentric rings
    ofSetLineWidth(1);
    for (int r = 1; r <= 4; ++r) {
        ofSetColor(40, 60, 90, 80);
        ofNoFill();
        ofDrawCircle(0, 0, radius * (r / 4.0f));
    }

    // Two waveform petals (ch1 + ch2)
    ofNoFill();
    ofSetLineWidth(2);
    auto drawPetal = [&](const std::vector<float>& trace, ofColor col) {
        ofSetColor(col);
        ofBeginShape();
        const std::size_t N = trace.size();
        for (std::size_t i = 0; i < N; ++i) {
            const float a = (i / static_cast<float>(N)) * TWO_PI;
            const float v = trace[i];
            const float r = radius * (0.55f + 0.40f * v);
            ofVertex(std::cos(a) * r, std::sin(a) * r);
        }
        ofEndShape(true);
    };
    // Couleurs des pétales pilotées par les fréquences :
    //   trace1 = pétale "haute fréquence" → hue glisse rouge avec lead
    //   trace2 = pétale "basse fréquence" → hue glisse bleu profond avec bass
    ofColor c1, c2;
    c1.setHsb(ofClamp(140.0f - lead_ * 140.0f, 0.0f, 255.0f),
              200.0f, 200.0f + 55.0f * lead_);
    c1.a = 220;
    c2.setHsb(ofClamp(160.0f + bass_ * 60.0f, 0.0f, 255.0f),
              200.0f, 200.0f + 55.0f * bass_);
    c2.a = 220;
    drawPetal(trace1_, c1);
    drawPetal(trace2_, c2);

    // Inner glowing core, modulated by kick
    ofFill();
    const float core = radius * (0.10f + kick_ * 0.18f);
    for (int g = 6; g >= 1; --g) {
        ofSetColor(255, 200, 80, 28 / g);
        ofDrawCircle(0, 0, core * g * 0.7f);
    }
    ofSetColor(255, 240, 180);
    ofDrawCircle(0, 0, core);

    // Beat shockwave
    if (shockA_ > 0.01f) {
        ofNoFill();
        ofSetLineWidth(3);
        ofSetColor(255, 200, 100, static_cast<int>(shockA_ * 200.0f));
        ofDrawCircle(0, 0, std::min(shockR_, radius * 1.4f));
    }

    ofPopMatrix();
    ofPopStyle();
}

} // namespace oscope
