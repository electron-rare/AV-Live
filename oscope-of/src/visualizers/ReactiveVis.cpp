#include "ReactiveVis.h"

namespace oscope {

void ReactiveVis::setup(int w, int h) {
    w_ = w; h_ = h;
    reloadShaders();
}

void ReactiveVis::reloadShaders() {
    bg_.load("shaders/bg");
}

void ReactiveVis::update(const VisFrame& frame) {
    time_ += ofGetLastFrameTime();
    auto& osc = frame.osc;
    bpm_ = osc.bpm();
    beat_ = osc.beat();
    // Lissage exponentiel pour éviter les jumps brutaux.
    auto smooth = [](float& s, float target) { s += (target - s) * 0.18f; };
    smooth(kick_,    osc.amp("kick"));
    smooth(hat_,     osc.amp("hat"));
    smooth(snare_,   osc.amp("snare"));
    smooth(clap_,    osc.amp("clap"));
    smooth(perc_,    osc.amp("perc"));
    smooth(melody_,  osc.amp("melody"));
    smooth(acid_,    osc.amp("acid"));
    smooth(harmony_, osc.amp("harmony"));
}

void ReactiveVis::draw(int x, int y, int w, int h) {
    if (!bg_.isLoaded()) {
        ofPushStyle();
        ofSetColor(8, 6, 16);
        ofDrawRectangle(x, y, w, h);
        ofPopStyle();
        return;
    }
    bg_.begin();
    bg_.setUniform2f("uResolution", w, h);
    bg_.setUniform1f("uTime", time_);
    bg_.setUniform1f("uBpm", bpm_);
    bg_.setUniform1i("uBeat", beat_);
    bg_.setUniform1f("uKick", kick_);
    bg_.setUniform1f("uHat", hat_);
    bg_.setUniform1f("uSnare", snare_);
    bg_.setUniform1f("uClap", clap_);
    bg_.setUniform1f("uPerc", perc_);
    bg_.setUniform1f("uMelody", melody_);
    bg_.setUniform1f("uAcid", acid_);
    bg_.setUniform1f("uHarmony", harmony_);
    ofDrawRectangle(x, y, w, h);
    bg_.end();
}

} // namespace oscope
