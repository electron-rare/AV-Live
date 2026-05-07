#include "PostFx.h"

namespace oscope {

void PostFx::setup(int w, int h) {
    resize(w, h);
    reloadShader();
}

void PostFx::resize(int w, int h) {
    if (w == w_ && h == h_ && ready_) return;
    w_ = std::max(1, w);
    h_ = std::max(1, h);
    ofFbo::Settings s;
    s.width = w_;
    s.height = h_;
    s.internalformat = GL_RGBA;
    s.numColorbuffers = 1;
    s.useDepth = false;
    s.useStencil = false;
    s.textureTarget = GL_TEXTURE_RECTANGLE_ARB;
    fboScene_.allocate(s);
    history_[0].allocate(s);
    history_[1].allocate(s);
    for (int i = 0; i < 2; ++i) {
        history_[i].begin();
        ofClear(0, 0, 0, 255);
        history_[i].end();
    }
    fboScene_.begin();
    ofClear(0, 0, 0, 255);
    fboScene_.end();
    ready_ = true;
}

void PostFx::reloadShader() {
    shader_.load("shaders/postfx");
}

void PostFx::beginScene() {
    if (!ready_) return;
    fboScene_.begin();
    ofClear(0, 0, 0, 255);
}

void PostFx::endScene() {
    if (!ready_) return;
    fboScene_.end();
}

void PostFx::triggerGlitch(float amount, float decaySeconds) {
    glitchPulse_ = std::max(glitchPulse_, amount);
    glitchDecay_ = decaySeconds;
}

void PostFx::update(float dt) {
    if (glitchPulse_ > 0.0f) {
        glitchPulse_ -= dt / glitchDecay_;
        if (glitchPulse_ < 0.0f) glitchPulse_ = 0.0f;
    }
}

void PostFx::draw(int x, int y, int w, int h) {
    if (!ready_) return;

    ofFbo& dst = history_[writeIdx_];
    ofFbo& src = history_[1 - writeIdx_];

    dst.begin();
    ofClear(0, 0, 0, 255);
    if (shader_.isLoaded()) {
        shader_.begin();
        shader_.setUniformTexture("uScene", fboScene_.getTexture(), 0);
        shader_.setUniformTexture("uPrev",  src.getTexture(),       1);
        shader_.setUniform2f("uRes", static_cast<float>(w_), static_cast<float>(h_));
        shader_.setUniform1f("uTime", ofGetElapsedTimef());
        shader_.setUniform1f("uChroma",       params.chroma);
        shader_.setUniform1f("uBloom",        params.bloom);
        shader_.setUniform1f("uRgbShift",     params.rgbShift);
        shader_.setUniform1f("uSat",          params.saturation);
        shader_.setUniform1f("uScan",         params.scanlines);
        shader_.setUniform1f("uVignette",     params.vignette);
        shader_.setUniform1f("uGrain",        params.filmGrain);
        shader_.setUniform1f("uPixelate",     params.pixelate);
        shader_.setUniform1f("uKaleido",      params.kaleido);
        shader_.setUniform1f("uFeedback",     params.feedback);
        shader_.setUniform1f("uFbZoom",       params.feedbackZoom);
        shader_.setUniform1f("uFbRot",        params.feedbackRot);
        const float gl = std::max(params.glitch, glitchPulse_);
        shader_.setUniform1f("uGlitch",       gl);
        shader_.setUniform1f("uGlitchProb",   params.glitchProb);

        // Any geometry works — frag samples manually. Use the scene texture
        // because its draw() emits the right textured quad.
        ofSetColor(255);
        fboScene_.getTexture().draw(0, 0, w_, h_);

        shader_.end();
    } else {
        ofSetColor(255);
        fboScene_.getTexture().draw(0, 0, w_, h_);
    }
    dst.end();

    ofSetColor(255);
    dst.draw(x, y, w, h);

    writeIdx_ = 1 - writeIdx_;
}

} // namespace oscope
