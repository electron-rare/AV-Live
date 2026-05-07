#include "WaveformVis.h"
#include <cmath>
#include <algorithm>

namespace oscope {

void WaveformVis::setup(int w, int h) {
    w_ = w;
    h_ = h;
    trace1_.assign(syntheticSize_, 0.0f);
    trace2_.assign(syntheticSize_, 0.0f);
    slowTrace_.assign(syntheticSize_, 0.0f);
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

        // Trace lente superposée — même ring, fenêtre slowMsPerDiv_×8 div.
        // Pour ne pas afficher uniquement des pics, on prend le max-abs de
        // chaque sous-tranche : envelope-style.
        if (showSlowOverlay_) {
            const float slowSec = (slowMsPerDiv_ * 0.001f) * divX_;
            std::size_t slowWin = static_cast<std::size_t>(
                std::max(static_cast<float>(winSamples + 1),
                         std::min(static_cast<float>(cap),
                                  slowSec * sampleRateHz_)));
            const std::size_t soff = (cap + ringHead_ - slowWin) % cap;
            const std::size_t bucket = std::max<std::size_t>(
                1, slowWin / slowTrace_.size());
            for (std::size_t i = 0; i < slowTrace_.size(); ++i) {
                const std::size_t k0 = i * bucket;
                float peak = 0.0f;
                for (std::size_t j = 0; j < bucket; ++j) {
                    const std::size_t idx = (soff + k0 + j) % cap;
                    const float v = 0.5f * (ring1_[idx] + ring2_[idx]);
                    const float av = v < 0.0f ? -v : v;
                    if (av > peak) peak = (v < 0.0f) ? -av : av;
                }
                slowTrace_[i] = peak;
            }
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

void WaveformVis::drawCircular(int cx, int cy, float baseR, float maxR) {
    ofPushStyle();
    ofPushMatrix();
    ofTranslate(cx, cy);

    // Cercle de référence (timeline) — discret, pour donner une sensation
    // d'horloge.
    ofNoFill();
    ofSetColor(0, 80, 50, 80);
    ofSetLineWidth(1);
    ofDrawCircle(0, 0, baseR);

    auto plotRing = [&](const std::vector<float>& trace, ofColor base,
                        float radius, float ampScale) {
        const int n = static_cast<int>(trace.size());
        if (n < 2) return;
        // Glow phosphor 3 passes
        for (int pass = 3; pass >= 1; --pass) {
            ofColor c = base;
            c.a = static_cast<unsigned char>(40 * pass);
            ofSetColor(c);
            ofSetLineWidth(2.0f * (4 - pass));
            ofBeginShape();
            for (int i = 0; i < n; ++i) {
                const float t = static_cast<float>(i) / (n - 1);
                const float a = t * TWO_PI - HALF_PI;
                const float r = radius + trace[i] * ampScale;
                ofVertex(std::cos(a) * r, std::sin(a) * r);
            }
            ofEndShape(true);  // closed loop
        }
    };

    const float band = (maxR - baseR);
    // Ordre : slow trace en arrière-plan, puis CH1 puis CH2 par-dessus.
    if (showSlowOverlay_ && !slowTrace_.empty()) {
        plotRing(slowTrace_, ofColor(80, 160, 200), baseR + band * 0.05f,
                 band * 0.45f);
    }
    plotRing(trace1_, ofColor(0,   255, 140), baseR + band * 0.30f,
             band * 0.20f);
    plotRing(trace2_, ofColor(255, 200,  60), baseR + band * 0.65f,
             band * 0.20f);

    ofPopMatrix();
    ofPopStyle();
}

void WaveformVis::draw(int x, int y, int w, int h) {
    if (circular_) {
        const float cx = x + w * 0.5f;
        const float cy = y + h * 0.5f;
        const float maxR = 0.46f * std::min(w, h);
        const float baseR = maxR * 0.50f;
        drawCircular(static_cast<int>(cx), static_cast<int>(cy), baseR, maxR);
        return;
    }
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

    // Trace lent en arrière-plan (sous les traces audio) — vue enveloppe /
    // drift, traversant tout l'écran. Cyan épais semi-transparent.
    if (showSlowOverlay_ && !slowTrace_.empty()) {
        ofSetColor(80, 160, 200, 110);
        ofSetLineWidth(4);
        ofBeginShape();
        const int n = static_cast<int>(slowTrace_.size());
        for (int i = 0; i < n; ++i) {
            const float px = x + (static_cast<float>(i) / (n - 1)) * w;
            const float py = y + h * 0.5f - slowTrace_[i] * (h * 0.40f);
            ofVertex(px, py);
        }
        ofEndShape(false);
    }

    // Glow phosphor : 3 passes décalées en alpha (au-dessus du slow trace)
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
    if (showSlowOverlay_) {
        ofSetColor(120, 220, 255);
        ofDrawBitmapString("Slow " + ofToString(slowMsPerDiv_, 1) + " ms/div",
                           x + 10, y + 96);
    }

    ofPopMatrix();
    ofPopStyle();
}

} // namespace oscope
