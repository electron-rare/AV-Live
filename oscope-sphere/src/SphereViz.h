#pragma once
#include "ofMain.h"
#include "SpectrogramBuffer.h"
#include <memory>
#include <vector>

// GL visual unit: an icosphere whose skin is the scrolling spectrogram.
// The northern hemisphere shows CH1, the southern shows CH2.
class SphereViz {
public:
    void setup(int icoIterations, int spectroWidth, int spectroHeight);

    // Advances the spectrogram by one column and uploads it.
    void pushSpectrogramColumn(const std::vector<float>& magCh1,
                               const std::vector<float>& magCh2);

    void drawSkin();
    void setColormap(int id) { colormapId_ = id; }

private:
    std::unique_ptr<oscope::SpectrogramBuffer> spectro_;
    ofVboMesh   mesh_;
    ofShader    shader_;
    ofTexture   spectroTex_;
    ofFloatPixels spectroPix_;
    float baseRadius_  = 200.0f;
    float scrollOffset_ = 0.0f;
    int   colormapId_  = 0;
};
