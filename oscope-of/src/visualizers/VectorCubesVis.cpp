#include "VectorCubesVis.h"

#include <cmath>

namespace oscope {

void VectorCubesVis::setup(int w, int h) {
    w_ = w; h_ = h;
    // Camera persp depuis l'arrière, regarde origine
    camera_.setPosition(0, 0, 12);
    camera_.lookAt(ofVec3f(0, 0, 0));
    camera_.setNearClip(0.1f);
    camera_.setFarClip(60.0f);

    // Grille 5x3x5 de cubes
    cubes_.clear();
    for (int z = -2; z <= 2; ++z) {
        for (int y = -1; y <= 1; ++y) {
            for (int x = -2; x <= 2; ++x) {
                Cube c;
                c.pos = ofVec3f(x * 1.6f, y * 1.6f, z * 1.6f);
                c.rotAxis = ofVec3f(
                    ofRandom(-1, 1), ofRandom(-1, 1), ofRandom(-1, 1)
                ).getNormalized();
                c.rotSpeed = ofRandom(20, 90);
                c.size = 0.7f;
                cubes_.push_back(c);
            }
        }
    }

    light_.setPosition(5, 5, 5);
    light_.setPointLight();
    light_.setDiffuseColor(ofFloatColor(1.0f, 0.85f, 0.5f));
    light_.setSpecularColor(ofFloatColor(1.0f, 1.0f, 0.9f));
}

void VectorCubesVis::update(const VisFrame& frame) {
    t_      += static_cast<float>(ofGetLastFrameTime());
    bass_    = frame.bands.bass;
    mid_     = frame.bands.mid;
    treble_  = frame.bands.treble;
    kick_    = frame.bands.kick;
    bpm_     = frame.osc.bpm();

    // La camera orbite lentement autour de la scène
    const float orbitR = 12.0f + std::sin(t_ * 0.3f) * 2.0f;
    const float orbitA = t_ * (0.15f + bpm_ * 0.0006f);
    camera_.setPosition(std::cos(orbitA) * orbitR,
                        std::sin(t_ * 0.21f) * 4.0f,
                        std::sin(orbitA) * orbitR);
    camera_.lookAt(ofVec3f(0, 0, 0));

    // Light position : tourne avec kick = pulse
    light_.setPosition(std::sin(t_ * 1.2f) * 6.0f,
                       4.0f + kick_ * 4.0f,
                       std::cos(t_ * 1.4f) * 6.0f);
    light_.setDiffuseColor(ofFloatColor(
        0.6f + 0.4f * mid_,
        0.4f + 0.5f * treble_,
        0.7f + 0.3f * bass_));
}

void VectorCubesVis::draw(int x, int y, int w, int h) {
    ofPushStyle();
    ofPushMatrix();

    // Setup viewport pour cette zone uniquement
    ofViewport(x, y, w, h, false);

    ofEnableDepthTest();
    ofEnableLighting();
    light_.enable();
    camera_.begin(ofRectangle(0, 0, w, h));

    for (std::size_t i = 0; i < cubes_.size(); ++i) {
        const auto& c = cubes_[i];
        ofPushMatrix();
        // Position pulsée par bass au global
        const ofVec3f p = c.pos * (1.0f + bass_ * 0.20f);
        ofTranslate(p.x, p.y, p.z);
        // Rotation propre par cube
        const float ang = t_ * c.rotSpeed + i * 17.0f;
        ofRotateRad(ang * DEG_TO_RAD, c.rotAxis.x, c.rotAxis.y, c.rotAxis.z);
        // Taille pulsée par kick
        const float s = c.size * (1.0f + kick_ * 0.4f);
        // Couleur par index, modulée par fréquences
        ofColor col;
        col.setHsb(static_cast<int>((i * 11 + t_ * 30)) % 255,
                   200,
                   180 + static_cast<int>(75 * (mid_ + treble_)));
        ofSetColor(col);
        material_.setDiffuseColor(col);
        material_.setSpecularColor(ofFloatColor(1.0f));
        material_.setShininess(64.0f);
        material_.begin();
        ofDrawBox(0, 0, 0, s, s, s);
        material_.end();
        // Wireframe au-dessus pour le côté vector
        ofSetColor(255, 230, 180, 200);
        ofNoFill();
        ofDrawBox(0, 0, 0, s * 1.02f, s * 1.02f, s * 1.02f);
        ofFill();
        ofPopMatrix();
    }

    camera_.end();
    light_.disable();
    ofDisableLighting();
    ofDisableDepthTest();

    // Restore le viewport plein
    ofViewport(0, 0, ofGetWidth(), ofGetHeight(), false);
    ofPopMatrix();
    ofPopStyle();
}

} // namespace oscope
