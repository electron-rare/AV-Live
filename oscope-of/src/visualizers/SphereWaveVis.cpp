#include "SphereWaveVis.h"

#include <cmath>
#include <algorithm>

namespace oscope {

namespace {
constexpr std::size_t kFftSize = 1024;
}

void SphereWaveVis::setup(int w, int h) {
    w_ = w; h_ = h;
    fft_ = std::make_unique<FFT>(kFftSize);
    mono_.assign(kFftSize, 0.0f);

    // Construit sphère paramétrique (kNU × kNV) avec faces triangulées
    sphere_.clear();
    baseR_.clear();
    for (int u = 0; u < kNU; ++u) {
        for (int v = 0; v < kNV; ++v) {
            float lon = (u / static_cast<float>(kNU)) * TWO_PI;
            float lat = (v / static_cast<float>(kNV - 1)) * PI - HALF_PI;
            float x = std::cos(lat) * std::cos(lon);
            float y = std::sin(lat);
            float z = std::cos(lat) * std::sin(lon);
            sphere_.addVertex(ofVec3f(x, y, z) * 2.0f);
            sphere_.addNormal(ofVec3f(x, y, z));
            baseR_.push_back(2.0f);
        }
    }
    // Faces (quad → 2 triangles), wrap U
    for (int u = 0; u < kNU; ++u) {
        for (int v = 0; v < kNV - 1; ++v) {
            int i00 = u * kNV + v;
            int i01 = u * kNV + v + 1;
            int i10 = ((u + 1) % kNU) * kNV + v;
            int i11 = ((u + 1) % kNU) * kNV + v + 1;
            sphere_.addTriangle(i00, i10, i11);
            sphere_.addTriangle(i00, i11, i01);
        }
    }

    camera_.setNearClip(0.1f);
    camera_.setFarClip(40.0f);
    light_.setPointLight();
    light_.setDiffuseColor(ofFloatColor(1.0f, 0.9f, 0.7f));
    light_.setSpecularColor(ofFloatColor(1.0f));
}

void SphereWaveVis::update(const VisFrame& frame) {
    t_ += static_cast<float>(ofGetLastFrameTime());
    bass_   = frame.bands.bass;
    mid_    = frame.bands.mid;
    treble_ = frame.bands.treble;
    kick_   = frame.bands.kick;
    bpm_    = frame.osc.bpm();

    // FFT depuis mono Hantek
    const auto& ch1 = frame.ch1;
    const auto& ch2 = frame.ch2;
    const std::size_t n = std::min({ch1.size(), ch2.size(), kFftSize});
    if (n > 16 && fft_) {
        std::fill(mono_.begin(), mono_.end(), 0.0f);
        for (std::size_t i = 0; i < n; ++i)
            mono_[i] = 0.5f * (ch1[i] + ch2[i]);
        fft_->magnitude(mono_, mag_);
    }

    // Mise à jour des vertex de la sphère : rayon = base + FFT_à_cet_angle
    if (mag_.empty()) return;
    auto& verts = sphere_.getVertices();
    for (int u = 0; u < kNU; ++u) {
        for (int v = 0; v < kNV; ++v) {
            const std::size_t idx = u * kNV + v;
            // Map (u,v) → bin FFT (log scale) ; chaque longitude couvre une plage
            const float t = static_cast<float>(u) / kNU;
            const std::size_t bin = static_cast<std::size_t>(
                std::pow(t, 2.0f) * (mag_.size() - 1));
            const float magdb = 20.0f * std::log10(std::max(mag_[bin], 1e-6f)) + 60.0f;
            const float fftAmp = std::max(0.0f, std::min(1.0f, magdb / 60.0f));
            // + waveform oscillation par latitude
            const std::size_t wIdx = (v * 4 + u) % std::min(n, kFftSize);
            const float wave = (n > 16) ? mono_[wIdx] * 0.3f : 0.0f;

            const float r = baseR_[idx] + fftAmp * 1.2f + wave;
            const ofVec3f n_ = sphere_.getNormal(idx);
            verts[idx] = n_ * r;
        }
    }
}

void SphereWaveVis::draw(int x, int y, int w, int h) {
    ofPushStyle();
    ofPushMatrix();
    ofViewport(x, y, w, h, false);
    ofEnableDepthTest();
    ofEnableLighting();

    // Camera orbite
    const float orbitR = 7.0f;
    const float orbitA = t_ * 0.25f;
    camera_.setPosition(std::cos(orbitA) * orbitR,
                        std::sin(t_ * 0.18f) * 2.0f,
                        std::sin(orbitA) * orbitR);
    camera_.lookAt(ofVec3f(0, 0, 0));
    light_.setPosition(std::sin(t_ * 0.7f) * 5.0f,
                       3.0f + kick_ * 4.0f,
                       std::cos(t_ * 0.9f) * 5.0f);
    light_.enable();
    camera_.begin(ofRectangle(0, 0, w, h));

    // Couleur cycle hue + audio
    ofColor col;
    col.setHsb(static_cast<int>(std::fmod(t_ * 25.0f, 255.0f)),
               180,
               180 + static_cast<int>(75.0f * (mid_ + treble_) * 0.5f));
    material_.setDiffuseColor(col);
    material_.setSpecularColor(ofFloatColor(1.0f, 0.9f, 0.8f));
    material_.setShininess(48.0f);

    // Solid pass
    ofSetColor(col);
    material_.begin();
    sphere_.drawFaces();
    material_.end();

    // Wireframe par-dessus
    ofSetColor(255, 240, 200, 140);
    sphere_.drawWireframe();

    camera_.end();
    light_.disable();
    ofDisableLighting();
    ofDisableDepthTest();
    ofViewport(0, 0, ofGetWidth(), ofGetHeight(), false);
    ofPopMatrix();
    ofPopStyle();
}

} // namespace oscope
