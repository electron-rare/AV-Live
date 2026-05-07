#pragma once

// ShaderVis : visualizer fullscreen-quad piloté par un fragment shader.
// Charge n'importe quel shader (path = "shaders/<nom>") et passe les
// uniforms standards uTime / uRes + bandes audio (bass/mid/treble/kick).
// Sert de wrapper léger pour les FX type demoscene (metaballs, voronoi,
// twister, plasma fbm, rotozoomer, etc.) sans code redondant.

#include "Visualizer.h"
#include "ofMain.h"

#include <string>

namespace oscope {

class ShaderVis : public Visualizer {
public:
    explicit ShaderVis(const std::string& shaderPath)
        : shaderPath_(shaderPath) {}

    void setup(int w, int h) override { w_ = w; h_ = h; reloadShaders(); }
    void update(const VisFrame& frame) override {
        bass_   = frame.bands.bass;
        mid_    = frame.bands.mid;
        treble_ = frame.bands.treble;
        kick_   = frame.bands.kick;
        bpm_    = frame.osc.bpm();
    }
    void draw(int x, int y, int w, int h) override {
        if (!shader_.isLoaded()) {
            ofPushStyle();
            ofSetColor(60);
            ofDrawRectangle(x, y, w, h);
            ofSetColor(255, 80, 80);
            ofDrawBitmapString(shaderPath_ + " missing", x + 12, y + 24);
            ofPopStyle();
            return;
        }
        shader_.begin();
        shader_.setUniform2f("uRes",   static_cast<float>(w), static_cast<float>(h));
        shader_.setUniform1f("uTime",  ofGetElapsedTimef());
        shader_.setUniform1f("uBass",  bass_);
        shader_.setUniform1f("uMid",   mid_);
        shader_.setUniform1f("uTreble",treble_);
        shader_.setUniform1f("uKick",  kick_);
        shader_.setUniform1f("uBpm",   bpm_);
        ofDrawRectangle(x, y, w, h);
        shader_.end();
    }
    void reloadShaders() override { shader_.load(shaderPath_); }

private:
    std::string shaderPath_;
    int   w_ = 0, h_ = 0;
    float bass_ = 0, mid_ = 0, treble_ = 0, kick_ = 0, bpm_ = 120;
    ofShader shader_;
};

} // namespace oscope
