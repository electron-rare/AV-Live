#include "SphereViz.h"
#include <algorithm>

void SphereViz::setup(int icoIterations, int spectroWidth, int spectroHeight,
                      int waveformLen) {
    waveformLen_ = waveformLen;
    spectro_ = std::make_unique<oscope::SpectrogramBuffer>(spectroWidth,
                                                           spectroHeight);

    ofIcoSpherePrimitive ico(baseRadius_, icoIterations);
    ofMesh src = ico.getMesh();
    mesh_.clear();
    mesh_.addVertices(src.getVertices());
    mesh_.addNormals(src.getNormals());
    mesh_.addIndices(src.getIndices());

    // ofDisableArbTex() is a global, app-wide GL state change: it makes all
    // textures use normalized [0,1] coordinates. oscope-sphere has a single
    // SphereViz so this is safe; revisit if other ARB-texture components are
    // ever added.
    ofDisableArbTex();
    spectroPix_.allocate(spectroWidth, spectroHeight, OF_PIXELS_GRAY);
    spectroPix_.set(0.0f);
    spectroTex_.allocate(spectroPix_);
    spectroTex_.setTextureWrap(GL_REPEAT, GL_CLAMP_TO_EDGE);
    spectroTex_.setTextureMinMagFilter(GL_LINEAR, GL_LINEAR);

    wavePix_.allocate(waveformLen, 2, OF_PIXELS_GRAY);
    wavePix_.set(0.0f);
    waveTex_.allocate(wavePix_);
    waveTex_.setTextureWrap(GL_REPEAT, GL_CLAMP_TO_EDGE);
    waveTex_.setTextureMinMagFilter(GL_LINEAR, GL_LINEAR);

    if (!shader_.load("shaders/sphere"))
        ofLogError("SphereViz") << "failed to load shaders/sphere";
}

void SphereViz::pushSpectrogramColumn(const std::vector<float>& magCh1,
                                      const std::vector<float>& magCh2) {
    spectro_->pushColumn(magCh1, magCh2);
    const std::vector<float>& d = spectro_->data();
    std::copy(d.begin(), d.end(), spectroPix_.getData());
    spectroTex_.loadData(spectroPix_);
    scrollOffset_ = static_cast<float>(spectro_->writeIndex()) /
                    static_cast<float>(spectro_->width());
}

void SphereViz::setWaveform(const std::vector<float>& ch1,
                            const std::vector<float>& ch2) {
    float* px = wavePix_.getData();
    const int L = waveformLen_;
    auto fillRow = [&](const std::vector<float>& src, int row) {
        const int n = static_cast<int>(src.size());
        for (int i = 0; i < L; ++i) {
            float v = 0.0f;
            if (n > 0) {
                int idx = n - L + i;          // newest L samples
                if (idx < 0) idx = 0;
                v = src[idx];
            }
            px[row * L + i] = v;
        }
    };
    fillRow(ch1, 0);
    fillRow(ch2, 1);
    waveTex_.loadData(wavePix_);
}

void SphereViz::drawSkin() {
    shader_.begin();
    shader_.setUniformTexture("spectroTex", spectroTex_, 0);
    shader_.setUniformTexture("waveformTex", waveTex_, 1);
    shader_.setUniform1f("scrollOffset", scrollOffset_);
    shader_.setUniform1f("displaceAmount", displace_);
    shader_.setUniform1f("baseRadius", baseRadius_);
    shader_.setUniform1i("colormapId", colormapId_);
    shader_.setUniform1i("renderMode", 0);
    mesh_.draw();
    shader_.end();
}

void SphereViz::drawPoints() {
    shader_.begin();
    shader_.setUniformTexture("spectroTex", spectroTex_, 0);
    shader_.setUniformTexture("waveformTex", waveTex_, 1);
    shader_.setUniform1f("scrollOffset", scrollOffset_);
    shader_.setUniform1f("displaceAmount", displace_);
    shader_.setUniform1f("baseRadius", baseRadius_);
    shader_.setUniform1i("colormapId", colormapId_);
    shader_.setUniform1i("renderMode", 1);
    mesh_.drawVertices();
    shader_.end();
}
