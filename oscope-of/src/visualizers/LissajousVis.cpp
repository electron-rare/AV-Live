#include "LissajousVis.h"

namespace oscope {

void LissajousVis::setup(int w, int h) {
    w_ = w; h_ = h;
    ofFboSettings s;
    s.width = w; s.height = h;
    s.internalformat = GL_RGBA16F;
    s.numSamples = 0;
    s.useDepth = false;
    trail_.allocate(s);
    trail_.begin(); ofClear(0, 0, 0, 255); trail_.end();
    reloadShaders();
}

void LissajousVis::reloadShaders() {
    glow_.load("shaders/glow");
}

void LissajousVis::update(const VisFrame& frame) {
    // Détection beat -> flash kick (utilise l'amplitude kick).
    const float k = frame.osc.amp("kick");
    if (k > kickFlash_) kickFlash_ = k;
    kickFlash_ *= 0.92f;

    // Dessin dans le FBO trail avec fade.
    trail_.begin();
    ofPushStyle();
    ofEnableAlphaBlending();
    // Fade : rectangle noir semi-transparent.
    ofSetColor(0, 0, 0, 18);
    ofDrawRectangle(0, 0, w_, h_);

    // Trace CH1/CH2 en LINE_STRIP centré dans le FBO.
    const auto& ch1 = frame.ch1;
    const auto& ch2 = frame.ch2;
    const std::size_t n = std::min(ch1.size(), ch2.size());
    if (n >= 2) {
        const float cx = w_ * 0.5f;
        const float cy = h_ * 0.5f;
        const float scale = 0.45f * std::min(w_, h_);
        ofMesh mesh;
        mesh.setMode(OF_PRIMITIVE_LINE_STRIP);
        const float intensity = 0.6f + 0.4f * kickFlash_;
        ofFloatColor base(0.0f, 1.0f, 0.5f, intensity); // vert phosphor #00FF7F
        for (std::size_t i = 0; i < n; ++i) {
            mesh.addVertex(glm::vec3(cx + ch1[i] * scale,
                                     cy - ch2[i] * scale, 0.0f));
            mesh.addColor(base);
        }
        mesh.draw();
    }
    ofPopStyle();
    trail_.end();
}

void LissajousVis::draw(int x, int y, int w, int h) {
    ofPushStyle();
    ofEnableBlendMode(OF_BLENDMODE_ADD);
    if (glow_.isLoaded()) {
        glow_.begin();
        glow_.setUniformTexture("uTex", trail_.getTexture(), 0);
        glow_.setUniform2f("uTexel", 1.0f / w_, 1.0f / h_);
        glow_.setUniform1f("uIntensity", 1.2f + 0.6f * kickFlash_);
        trail_.draw(x, y, w, h);
        glow_.end();
    } else {
        trail_.draw(x, y, w, h);
    }
    ofPopStyle();
}

} // namespace oscope
