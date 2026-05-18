#pragma once
#include "ofMain.h"
#include "SpectrogramBuffer.h"
#include <memory>
#include <vector>

// GL visual unit: an icosphere skinned by the scrolling spectrogram and
// displaced radially by the live waveform. Northern hemisphere = CH1,
// southern = CH2.
class SphereViz {
public:
    void setup(int icoIterations, int spectroWidth, int spectroHeight,
               int waveformLen);

    void pushSpectrogramColumn(const std::vector<float>& magCh1,
                               const std::vector<float>& magCh2);
    void setWaveform(const std::vector<float>& ch1,
                     const std::vector<float>& ch2);

    void drawSkin();
    void setColormap(int id) { colormapId_ = id; }

private:
    std::unique_ptr<oscope::SpectrogramBuffer> spectro_;
    ofVboMesh     mesh_;
    ofShader      shader_;
    ofTexture     spectroTex_;
    ofTexture     waveTex_;
    ofFloatPixels spectroPix_;
    ofFloatPixels wavePix_;
    int   waveformLen_ = 0;
    float baseRadius_  = 200.0f;
    float scrollOffset_ = 0.0f;
    float displace_    = 0.18f;
    int   colormapId_  = 0;
};
