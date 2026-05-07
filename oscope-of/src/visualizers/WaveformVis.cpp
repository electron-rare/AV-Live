#include "WaveformVis.h"
#include <cmath>
#include <algorithm>

namespace oscope {

void WaveformVis::setup(int w, int h) {
    w_ = w;
    h_ = h;
    trace1_.assign(syntheticSize_, 0.0f);
    trace2_.assign(syntheticSize_, 0.0f);
}

void WaveformVis::update(const VisFrame& frame) {
    const auto& osc = frame.osc;

    // Pulse de beat : déclenche un envelope decay quand /sync/beat tick
    int b = osc.beat();
    if (b != prevBeat_) {
        beatPhase_ = 1.0f;
        prevBeat_ = b;
    }
    beatPhase_ *= 0.92f;

    // Si Hantek a fourni des samples, on les copie tels quels
    if (frame.ch1.size() > 16) {
        std::size_t n = std::min(frame.ch1.size(), trace1_.size());
        for (std::size_t i = 0; i < n; ++i) {
            trace1_[i] = frame.ch1[i];
            trace2_[i] = (i < frame.ch2.size()) ? frame.ch2[i] : 0.0f;
        }
        if (n < trace1_.size()) {
            std::fill(trace1_.begin() + n, trace1_.end(), 0.0f);
            std::fill(trace2_.begin() + n, trace2_.end(), 0.0f);
        }
        return;
    }

    // Sinon : synthèse à partir des audio meters reçus en OSC
    const float kick   = osc.amp("kick");
    const float snare  = osc.amp("snare");
    const float melody = osc.amp("melody");
    const float hat    = osc.amp("hat");
    const float bpm    = std::max(60.0f, std::min(240.0f, osc.bpm()));

    // Fréquence porteuse modulée par melody
    const float carrierHz = 220.0f + melody * 1800.0f;
    const float sampleRate = 48000.0f;
    const float dphi = ofWrap(2.0f * PI * carrierHz / sampleRate, 0.0f, 1e9f);

    // Sub-bass kick
    const float subHz = 60.0f;
    const float dsub = 2.0f * PI * subHz / sampleRate;

    for (int i = 0; i < syntheticSize_; ++i) {
        phase_ += dphi;
        if (phase_ > 1e6f) phase_ = std::fmod(phase_, 2.0f * PI);
        const float t = static_cast<float>(i) / static_cast<float>(syntheticSize_);

        const float carrier = std::sin(phase_) * (0.3f + melody * 0.6f);
        const float sub     = std::sin(t * dsub * syntheticSize_) * kick * (0.4f + beatPhase_ * 0.6f);
        const float noise   = (ofRandom(-1.0f, 1.0f)) * (snare * 0.4f + hat * 0.25f);
        const float ch1     = (carrier + sub + noise) * (0.6f + beatPhase_ * 0.4f);

        const float carrier2 = std::sin(phase_ * 1.5f + 0.7f) * (0.25f + melody * 0.5f);
        const float ch2      = carrier2 + sub * 0.7f + noise * 0.6f;

        trace1_[i] = std::tanh(ch1);
        trace2_[i] = std::tanh(ch2 * 0.9f);
    }
}

void WaveformVis::draw(int x, int y, int w, int h) {
    ofPushStyle();
    ofPushMatrix();

    // Fond noir + grille verte CRT
    ofFill();
    ofSetColor(8, 12, 8);
    ofDrawRectangle(x, y, w, h);

    ofNoFill();
    ofSetLineWidth(1);
    ofSetColor(0, 80, 50, 80);
    for (int i = 0; i <= divX_; ++i) {
        const float gx = x + (w / divX_) * i;
        ofDrawLine(gx, y, gx, y + h);
    }
    for (int j = 0; j <= divY_; ++j) {
        const float gy = y + (h / divY_) * j;
        ofDrawLine(x, gy, x + w, gy);
    }
    // Centre lines, plus marqués
    ofSetColor(0, 140, 80, 130);
    ofDrawLine(x, y + h * 0.5f, x + w, y + h * 0.5f);
    ofDrawLine(x + w * 0.5f, y, x + w * 0.5f, y + h);

    auto plot = [&](const std::vector<float>& trace, ofColor color, float yOff) {
        ofSetColor(color);
        ofSetLineWidth(2);
        ofBeginShape();
        const int n = static_cast<int>(trace.size());
        for (int i = 0; i < n; ++i) {
            const float px = x + (static_cast<float>(i) / (n - 1)) * w;
            const float py = y + yOff + trace[i] * (h * 0.22f);
            ofVertex(px, py);
        }
        ofEndShape(false);
    };

    // Glow phosphor : 3 passes décalées en alpha
    for (int pass = 3; pass >= 1; --pass) {
        const float a = 30.0f * pass;
        plot(trace1_, ofColor(0, 255, 140, static_cast<int>(a)), h * 0.30f);
        plot(trace2_, ofColor(255, 200, 60, static_cast<int>(a)), h * 0.70f);
    }

    // HUD
    ofSetColor(160, 220, 180);
    const float vdiv1 = 0.5f;
    const float vdiv2 = 0.5f;
    const float tdiv  = 5.0f; // ms/div approximatif
    ofDrawBitmapString("CH1  " + ofToString(vdiv1, 2) + " V/div", x + 10, y + 16);
    ofDrawBitmapString("CH2  " + ofToString(vdiv2, 2) + " V/div", x + 10, y + 32);
    ofDrawBitmapString("Time " + ofToString(tdiv, 1) + " ms/div", x + 10, y + 48);
    ofDrawBitmapString("Trig auto", x + 10, y + 64);

    ofPopMatrix();
    ofPopStyle();
}

} // namespace oscope
