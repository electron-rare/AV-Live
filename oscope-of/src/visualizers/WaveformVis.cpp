#include "WaveformVis.h"
#include <cmath>
#include <algorithm>

namespace oscope {

void WaveformVis::setup(int w, int h) {
    w_ = w;
    h_ = h;
    trace1_.assign(syntheticSize_, 0.0f);
    trace2_.assign(syntheticSize_, 0.0f);
    // Ring d'historique : assez grand pour que le timebase puisse aller
    // jusqu'à ~125 ms à 8 MS/s (ou 1 s à 1 MS/s). 1 M floats ≈ 4 Mo par
    // canal, soit 8 Mo total — acceptable pour une vue scope live.
    ring1_.assign(1 << 20, 0.0f);
    ring2_.assign(1 << 20, 0.0f);
    ringHead_ = 0;
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

    // Si Hantek a fourni des samples, on alimente le ring d'historique
    if (frame.ch1.size() > 16) {
        const std::size_t cap = ring1_.size();
        const std::size_t n = std::min(frame.ch1.size(), cap);
        for (std::size_t i = 0; i < n; ++i) {
            ring1_[ringHead_] = frame.ch1[i];
            ring2_[ringHead_] = (i < frame.ch2.size()) ? frame.ch2[i] : 0.0f;
            ringHead_ = (ringHead_ + 1) % cap;
        }

        // Mode FREEZE — scrollSpeed_ ~ 0 : on n'actualise pas la fenêtre
        // affichée, le trace gèle tel qu'il était (utile pour analyser).
        if (scrollSpeed_ < 0.01f) return;

        // Largeur de la fenêtre = timebase × divisions, convertie en samples.
        // (sampleRate * (ms/div × divX) / 1000). On NE clamp PAS à
        // trace1_.size() : on downsample lors du remplissage du trace, ce
        // qui rend le slider timebase réellement effectif.
        const float winSec   = (timeMsPerDiv_ * 0.001f) * divX_;
        std::size_t winSamples = static_cast<std::size_t>(
            std::max(64.0f, std::min(static_cast<float>(cap),
                                     winSec * sampleRateHz_)));

        // Position de lecture : tail = head - winSamples (mode freeze) ou
        // tail décalé pour un effet de scroll continu.
        const std::size_t off = (cap + ringHead_ - winSamples) % cap;
        for (std::size_t i = 0; i < trace1_.size(); ++i) {
            const float t = static_cast<float>(i) /
                            static_cast<float>(trace1_.size() - 1);
            const std::size_t k = static_cast<std::size_t>(t * (winSamples - 1));
            const std::size_t idx = (off + k) % cap;
            trace1_[i] = ring1_[idx];
            trace2_[i] = ring2_[idx];
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
    ofDrawBitmapString("CH1  " + ofToString(vdiv1, 2) + " V/div", x + 10, y + 16);
    ofDrawBitmapString("CH2  " + ofToString(vdiv2, 2) + " V/div", x + 10, y + 32);
    ofDrawBitmapString("Time " + ofToString(timeMsPerDiv_, 2) + " ms/div",
                       x + 10, y + 48);
    ofDrawBitmapString(scrollSpeed_ < 0.01f ? "FROZEN" : "ROLL",
                       x + 10, y + 64);
    ofDrawBitmapString("Sr   " + ofToString(sampleRateHz_ * 1e-6f, 1) + " MS/s",
                       x + 10, y + 80);

    ofPopMatrix();
    ofPopStyle();
}

} // namespace oscope
