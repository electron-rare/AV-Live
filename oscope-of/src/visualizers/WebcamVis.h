#pragma once

// Webcam + ofxOpenCv pipeline + overlay du skeleton recu via OSC
// (/data/pose/skel <idx> <avg> <x0 y0 c0 ... x16 y16 c16>).
//
// La capture webcam est faite EN LOCAL par oF (ofVideoGrabber). La
// detection de pose tourne dans le pont Python (data_feeds/feeds/pose.py)
// sur la MEME webcam que celle que oF ouvre ? Non : sur Mac, une seule
// app peut grabber la camera. On a 2 strategies :
//
//   A) oF capture localement et applique du fx OpenCV (contours, frame
//      diff, threshold, optical flow). Pas de detection de pose oF-side.
//      Le pont Python NE tourne PAS le worker pose.
//
//   B) Le pont Python grabbe la webcam, fait la detection, et expose un
//      stream MJPEG/UDP en plus de l'OSC. oF lit ce stream comme
//      ofVideoGrabber. (TODO si necessaire — non implemente ici.)
//
// Choix par defaut : A. setEnableLocalCapture(false) pour mode B.

#include "Visualizer.h"
#include "ofMain.h"
#include "ofxOpenCv.h"

#include <array>
#include <vector>

namespace oscope {

class WebcamVis : public Visualizer {
public:
    void setup(int w, int h) override;
    void update(const VisFrame& frame) override;
    void draw(int x, int y, int w, int h) override;

    // Live tweaks.
    void setEnableLocalCapture(bool b) { localCapture_ = b; }
    void setThreshold(float v)         { threshold_   = ofClamp(v, 0.f, 255.f); }
    void setEdgeAmount(float v)        { edgeAmount_  = ofClamp(v, 0.f, 1.f); }
    void setSkeletonAlpha(float v)     { skelAlpha_   = ofClamp(v, 0.f, 1.f); }
    void setMode(int m)                { mode_ = m; } // 0 raw 1 edges 2 thresh 3 diff
    void setMirror(bool b)             { mirror_ = b; }

private:
    int   w_ = 0, h_ = 0;
    int   camW_ = 640, camH_ = 480;
    bool  localCapture_ = true;
    bool  cameraOk_     = false;
    bool  mirror_       = true;

    ofVideoGrabber       grabber_;
    ofxCvColorImage      colorImg_;
    ofxCvGrayscaleImage  grayImg_;
    ofxCvGrayscaleImage  prevGray_;
    ofxCvGrayscaleImage  diffImg_;
    ofxCvGrayscaleImage  edgesImg_;
    ofxCvGrayscaleImage  threshImg_;
    bool                 haveFrame_ = false;

    int   mode_      = 0;
    float threshold_ = 80.0f;
    float edgeAmount_ = 0.5f;
    float skelAlpha_  = 1.0f;

    // Cache du skeleton OSC : 17 keypoints x (x,y,conf), pour le sujet 0.
    struct Kp { float x = 0, y = 0, c = 0; };
    std::array<Kp, 17> skel_{};
    float skelAvgConf_ = 0.0f;
    int   personCount_ = 0;
    double lastSkelT_ = -1.0;
};

} // namespace oscope
