#include "TunnelVis.h"

namespace oscope {

void TunnelVis::setup(int w, int h) { w_ = w; h_ = h; reloadShaders(); }

void TunnelVis::reloadShaders() { shader_.load("shaders/tunnel"); }

void TunnelVis::update(const VisFrame& frame) {
    // Fréquences extraites du signal Hantek (FFT du ring downsamplé).
    // bpm/pad restent OSC car ce sont des métadonnées de timing/pad pas
    // déductibles d'une FFT brute.
    bpm_   = frame.osc.bpm();
    pad_   = frame.osc.amp("pad");
    kick_  = frame.bands.kick;
    bass_  = frame.bands.bass;
    lead_  = frame.bands.mid + frame.bands.treble * 0.5f;
    snare_ = frame.bands.snare;

    // Direction : lerp lente vers +1 si la balance HF (lead) > LF (bass),
    // -1 sinon. Le signe contrôle le sens de défilement et le sens du twist.
    const float dirTarget = (lead_ - bass_) > 0.05f ? 1.0f
                          : (bass_ - lead_) > 0.05f ? -1.0f
                          : direction_;
    direction_ += (dirTarget - direction_) * 0.04f;

    // Vitesse : base BPM + boost sur kick, signée par direction_.
    const float speed = (0.6f + bpm_ * 0.012f + kick_ * 1.5f) * direction_;
    travel_ += static_cast<float>(ofGetLastFrameTime()) * speed;

    // 3D — Banking (roll) : la nef s'incline. Composante kinétique de base
    // (oscillation sinusoïdale toujours présente) + composante audio.
    const float t = ofGetElapsedTimef();
    const float rollTarget = std::sin(t * 0.5f) * 0.35f
        + (lead_ - bass_) * 1.2f
        + std::sin(t * 1.7f) * 0.25f * (kick_ + 0.15f);
    roll_ += (rollTarget - roll_) * 0.08f;

    // 3D — Pan : le vanishing point se déplace vraiment, en figure de
    // Lissajous lente toujours active + impulsions sur kick/snare/bass.
    // Amplitudes max ~0.55 (vs 0.15 avant) → mouvement franc.
    const float baseX = std::sin(t * 0.31f) * 0.30f
                      + std::sin(t * 0.83f) * 0.12f;
    const float baseY = std::cos(t * 0.42f) * 0.25f
                      + std::cos(t * 1.13f) * 0.10f;
    const float panTargetX = baseX
        + (snare_ - 0.4f) * 0.8f * snare_
        + (lead_ - bass_) * 0.4f;
    const float panTargetY = baseY
        - kick_ * 0.6f
        - bass_ * 0.3f;
    panX_ += (panTargetX - panX_) * 0.12f;
    panY_ += (panTargetY - panY_) * 0.12f;

    // Tournant — la phase de courbure avance avec la vitesse de défilement
    // (corrélée à travel_) pour que le virage défile en même temps qu'on
    // progresse. L'amplitude est pilotée par la balance LF/HF + un floor
    // qui garantit qu'il y a toujours un léger virage.
    const float dt = static_cast<float>(ofGetLastFrameTime());
    curvePhase_ += dt * (1.2f + bpm_ * 0.005f) * direction_;
    const float curveTarget = 0.04f
        + std::abs(lead_ - bass_) * 0.10f
        + bass_ * 0.12f
        + std::sin(t * 0.21f) * 0.03f;
    curveAmp_ += (curveTarget - curveAmp_) * 0.05f;
}

void TunnelVis::draw(int x, int y, int w, int h) {
    if (!shader_.isLoaded()) {
        ofPushStyle();
        ofSetColor(40);
        ofDrawRectangle(x, y, w, h);
        ofSetColor(255, 80, 80);
        ofDrawBitmapString("tunnel shader missing", x + 12, y + 24);
        ofPopStyle();
        return;
    }
    shader_.begin();
    shader_.setUniform2f("uRes",  static_cast<float>(w), static_cast<float>(h));
    shader_.setUniform1f("uTime", ofGetElapsedTimef());
    shader_.setUniform1f("uTravel", travel_);
    shader_.setUniform1f("uBpm",  bpm_);
    shader_.setUniform1f("uKick", kick_);
    shader_.setUniform1f("uBass", bass_);
    shader_.setUniform1f("uLead", lead_);
    shader_.setUniform1f("uPad",  pad_);
    // Taille de tile pilotée par les fréquences :
    // - axe Z (profondeur) : bass loud → grosses tuiles (uTileZ bas)
    // - axe angulaire        : lead loud → tuiles fines    (uTileX haut)
    const float tileZ = ofLerp(3.0f, 0.5f, std::min(1.0f, bass_));
    const float tileX = ofLerp(8.0f, 32.0f, std::min(1.0f, lead_));
    shader_.setUniform1f("uTileZ", tileZ);
    shader_.setUniform1f("uTileX", tileX);
    shader_.setUniform1f("uDirection", direction_);
    shader_.setUniform1f("uRoll", roll_);
    shader_.setUniform2f("uPan",  panX_, panY_);
    shader_.setUniform1f("uCurveAmp",   curveAmp_);
    shader_.setUniform1f("uCurvePhase", curvePhase_);
    ofDrawRectangle(x, y, w, h);
    shader_.end();
}

} // namespace oscope
