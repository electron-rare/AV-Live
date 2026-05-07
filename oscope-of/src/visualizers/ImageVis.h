#pragma once

// ImageVis : charge un PNG et l'affiche en background animé.
// Animations : zoom pulsé sur kick, slow drift, hue cycle, scanlines CRT,
// flicker pour effet rétro.

#include "Visualizer.h"
#include "ofMain.h"

#include <string>

namespace oscope {

class ImageVis : public Visualizer {
public:
    explicit ImageVis(const std::string& spritePath)
        : spritePath_(spritePath) {}

    void setup(int w, int h) override {
        w_ = w; h_ = h;
        img_.load(spritePath_);
        if (img_.isAllocated()) {
            img_.setImageType(OF_IMAGE_COLOR_ALPHA);
        }
    }

    void update(const VisFrame& frame) override {
        t_     += static_cast<float>(ofGetLastFrameTime());
        bass_   = frame.bands.bass;
        mid_    = frame.bands.mid;
        treble_ = frame.bands.treble;
        kick_   = frame.bands.kick;
    }

    void draw(int x, int y, int w, int h) override {
        if (!img_.isAllocated()) {
            ofPushStyle();
            ofSetColor(40);
            ofDrawRectangle(x, y, w, h);
            ofSetColor(255, 80, 80);
            ofDrawBitmapString("sprite missing : " + spritePath_, x+12, y+24);
            ofPopStyle();
            return;
        }
        ofPushStyle();
        // Fond noir
        ofSetColor(0);
        ofDrawRectangle(x, y, w, h);

        // Calcule taille image affichée — fit dans la moitié de l'écran
        const float aspect = static_cast<float>(img_.getWidth()) /
                             std::max(1.0f, static_cast<float>(img_.getHeight()));
        float drawH = static_cast<float>(h) * 0.65f;
        float drawW = drawH * aspect;
        if (drawW > w * 0.85f) {
            drawW = w * 0.85f;
            drawH = drawW / aspect;
        }
        // Pulse sur kick + lente respiration
        const float pulse = 1.0f + kick_ * 0.15f
                          + std::sin(t_ * 0.7f) * 0.04f;
        drawW *= pulse;
        drawH *= pulse;

        // Drift lent X/Y
        const float dx = std::sin(t_ * 0.3f) * (w * 0.04f);
        const float dy = std::cos(t_ * 0.4f) * (h * 0.03f);
        const float cx = x + w * 0.5f + dx;
        const float cy = y + h * 0.5f + dy;

        // Tint hue cycle léger sur les blancs/clairs (multiply mode visible)
        ofColor tint;
        tint.setHsb(static_cast<int>(std::fmod(t_ * 12.0f, 255.0f)),
                    50,
                    240);
        // Flicker pseudo-aléatoire occasionnel (vintage CRT)
        if (std::fmod(t_, 3.0f) < 0.05f) tint.a = 220;
        else tint.a = 255;

        // === Effets demoscene sur l'image ===
        const float ix = cx - drawW * 0.5f;
        const float iy = cy - drawH * 0.5f;

        // 1) Réflexion bas (mirror) — flip Y avec alpha gradient
        ofPushMatrix();
        ofTranslate(cx, iy + drawH * 1.95f);
        ofScale(1.0f, -0.7f, 1.0f);
        ofSetColor(255, 255, 255, 100);
        img_.draw(-drawW * 0.5f, 0, drawW, drawH);
        ofPopMatrix();

        // 2) Ghost trail derrière — 3 copies offsets
        for (int g = 3; g >= 1; --g) {
            const float ox = std::cos(t_ * 0.6f + g) * 12.0f * g;
            const float oy = std::sin(t_ * 0.5f + g) * 8.0f * g;
            ofSetColor(180, 200, 255, 50 / g);
            img_.draw(ix + ox, iy + oy, drawW, drawH);
        }

        // 3) Chromatic aberration RGB — 3 passes avec offset radial
        const float chroma = 4.0f + kick_ * 8.0f;
        ofEnableBlendMode(OF_BLENDMODE_ADD);
        ofSetColor(255, 0, 0, 80);
        img_.draw(ix - chroma, iy, drawW, drawH);
        ofSetColor(0, 0, 255, 80);
        img_.draw(ix + chroma, iy, drawW, drawH);
        ofDisableBlendMode();

        // 4) Image principale tinted
        ofSetColor(tint);
        img_.draw(ix, iy, drawW, drawH);

        // 5) Twister wobble : image redessinée découpée en 8 bandes
        // horizontales avec offset X par sin(y, t). Effet "wave".
        if (std::fmod(t_, 6.0f) < 2.5f) {  // toggle pour pas saturer
            ofSetColor(255, 255, 255, 80);
            const int slices = 12;
            for (int s = 0; s < slices; ++s) {
                const float sy = drawH * s / slices;
                const float sh = drawH / slices + 1.0f;
                const float ox = std::sin(t_ * 2.0f + s * 0.7f) *
                                 (4.0f + bass_ * 12.0f);
                // Subset region : on dessine la bande cropée
                img_.drawSubsection(ix + ox, iy + sy, drawW, sh,
                                    0, img_.getHeight() * s / slices,
                                    img_.getWidth(),
                                    img_.getHeight() / slices + 1);
            }
        }

        // 6) Scanlines CRT
        ofSetColor(0, 0, 0, 40);
        for (int sy = y; sy < y + h; sy += 3) {
            ofDrawRectangle(x, sy, w, 1);
        }

        // 7) Glitch tear horizontal — bandes qui glissent aléatoirement
        if (kick_ > 0.5f) {
            ofSetColor(255, 100, 200,
                       static_cast<int>(60 * std::min(1.0f, kick_ * 2.0f)));
            const int gh = 3;
            for (int gy = static_cast<int>(iy); gy < iy + drawH; gy += 18) {
                const float gx = ofRandom(-30, 30);
                ofDrawRectangle(ix + gx, gy, drawW, gh);
            }
        }

        // 8) Boost luminance sur kick
        if (kick_ > 0.4f) {
            ofSetColor(255, 220, 180,
                       static_cast<int>(80 * std::min(1.0f, kick_ * 2.0f)));
            ofDrawRectangle(x, y, w, h);
        }
        ofPopStyle();
    }

private:
    std::string spritePath_;
    int     w_ = 0, h_ = 0;
    ofImage img_;
    float   t_ = 0.0f;
    float   bass_ = 0, mid_ = 0, treble_ = 0, kick_ = 0;
};

} // namespace oscope
