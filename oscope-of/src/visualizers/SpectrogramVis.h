#pragma once

// Spectrogramme FFT scrollant. Une nouvelle colonne est ajoutée à droite à
// chaque update, le contenu de la texture se décale d'1 pixel vers la gauche.

#include "../FFT.h"
#include "Visualizer.h"
#include "ofMain.h"

namespace oscope {

class SpectrogramVis : public Visualizer {
public:
    SpectrogramVis();
    void setup(int w, int h) override;
    void update(const VisFrame& frame) override;
    void draw(int x, int y, int w, int h) override;

private:
    ofFbo fbo_;
    ofFbo scratch_;
    int w_ = 0;
    int h_ = 0;
    FFT fft_;
    std::vector<float> mono_;
    std::vector<float> mag_;
};

} // namespace oscope
