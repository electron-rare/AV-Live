#include "SpectrogramVis.h"

#include <algorithm>
#include <cmath>

namespace oscope {

namespace {
constexpr std::size_t kFftSize = 1024;
}

SpectrogramVis::SpectrogramVis() : fft_(kFftSize) {}

void SpectrogramVis::setup(int w, int h) {
    w_ = w; h_ = h;
    ofFboSettings s;
    s.width = w; s.height = h;
    s.internalformat = GL_RGBA8;
    s.useDepth = false;
    fbo_.allocate(s);
    scratch_.allocate(s);
    fbo_.begin(); ofClear(0, 0, 0, 255); fbo_.end();
    scratch_.begin(); ofClear(0, 0, 0, 255); scratch_.end();
    mono_.resize(kFftSize, 0.0f);
}

void SpectrogramVis::update(const VisFrame& frame) {
    const auto& ch1 = frame.ch1;
    const auto& ch2 = frame.ch2;
    const std::size_t n = std::min({ch1.size(), ch2.size(), kFftSize});
    if (n == 0) return;
    // Mixe mono = (CH1 + CH2) / 2, prend les n derniers samples, padde avec 0.
    std::fill(mono_.begin(), mono_.end(), 0.0f);
    for (std::size_t i = 0; i < n; ++i) mono_[i] = 0.5f * (ch1[i] + ch2[i]);
    fft_.magnitude(mono_, mag_);

    // Décale fbo_ d'1 px vers la gauche en blittant dans scratch_, puis dessine
    // la nouvelle colonne tout à droite.
    scratch_.begin();
    ofClear(0, 0, 0, 255);
    fbo_.draw(-1, 0);
    // Nouvelle colonne : magnitude log-mappée -> hue bleu→violet→rouge.
    const std::size_t bins = mag_.size();
    for (int py = 0; py < h_; ++py) {
        // Mapping log-fréquence : bins du bas = basses, haut = aigus.
        const float t = 1.0f - static_cast<float>(py) / h_;
        const std::size_t bin = static_cast<std::size_t>(std::pow(t, 3.0f) * (bins - 1));
        const float magdb = 20.0f * std::log10(std::max(mag_[bin], 1e-6f)) + 60.0f;
        const float v = ofClamp(magdb / 60.0f, 0.0f, 1.0f);
        const float hue = 170.0f - 170.0f * v; // bleu (170) -> rouge (0)
        ofColor c; c.setHsb(hue, 200.0f * (0.4f + 0.6f * v), 255.0f * v);
        ofSetColor(c);
        ofDrawRectangle(w_ - 1, py, 1, 1);
    }
    scratch_.end();

    // Swap.
    fbo_.begin();
    ofClear(0, 0, 0, 255);
    scratch_.draw(0, 0);
    fbo_.end();
}

void SpectrogramVis::draw(int x, int y, int w, int h) {
    ofPushStyle();
    ofSetColor(255, 255, 255, 200);
    fbo_.draw(x, y, w, h);
    ofPopStyle();
}

void SpectrogramVis::drawCircular(int cx, int cy, float innerR, float outerR) {
    if (mag_.empty()) return;
    ofPushStyle();
    ofPushMatrix();
    ofTranslate(cx, cy);

    // Anneau central — chaque bin FFT occupe un secteur angulaire,
    // longueur radiale = magnitude, hue = bin (basses bleu → aigus rouge).
    const std::size_t bins = mag_.size();
    // On limite au quart bas (~Nyquist/4) car la moitié haute est très
    // sparse et brouille le rendu.
    const std::size_t shown = bins / 4;
    const float step = TWO_PI / static_cast<float>(shown);
    ofSetLineWidth(2);
    for (std::size_t i = 0; i < shown; ++i) {
        const float a = i * step;
        // Mapping log : on remap i sur le spectre log pour étaler les basses.
        const float t = std::pow(static_cast<float>(i) / shown, 0.55f);
        const std::size_t bin = static_cast<std::size_t>(t * (bins - 1));
        const float magdb = 20.0f * std::log10(std::max(mag_[bin], 1e-6f)) + 60.0f;
        const float v = ofClamp(magdb / 60.0f, 0.0f, 1.0f);

        // Hue colorisée par fréquence : 220 (bleu) → 0 (rouge) en hue HSB
        const float hue = 220.0f - 220.0f * t;
        ofColor col;
        col.setHsb(hue, 200.0f, 80.0f + 175.0f * v);
        col.a = static_cast<unsigned char>(120 + 135 * v);
        ofSetColor(col);

        const float r0 = innerR;
        const float r1 = innerR + (outerR - innerR) * v;
        const float ca = std::cos(a);
        const float sa = std::sin(a);
        ofDrawLine(ca * r0, sa * r0, ca * r1, sa * r1);
    }

    // Anneau interne discret pour cadrer
    ofNoFill();
    ofSetLineWidth(1);
    ofSetColor(60, 100, 140, 120);
    ofDrawCircle(0, 0, innerR);

    ofPopMatrix();
    ofPopStyle();
}

} // namespace oscope
