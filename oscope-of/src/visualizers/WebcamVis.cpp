#include "WebcamVis.h"

namespace oscope {

namespace {
// Squelette COCO (17 kp) — paires d'os.
constexpr std::array<std::pair<int, int>, 16> kBones = {{
    {0, 1}, {0, 2}, {1, 3}, {2, 4},
    {5, 6}, {5, 7}, {7, 9}, {6, 8}, {8, 10},
    {5, 11}, {6, 12}, {11, 12},
    {11, 13}, {13, 15}, {12, 14}, {14, 16},
}};
}

void WebcamVis::setup(int w, int h) {
    w_ = w; h_ = h;
    if (localCapture_) {
        grabber_.setDeviceID(0);
        grabber_.setDesiredFrameRate(30);
        cameraOk_ = grabber_.setup(camW_, camH_);
        if (!cameraOk_) {
            ofLogWarning("WebcamVis") << "camera unavailable, fallback to skeleton-only";
        } else {
            colorImg_.allocate(camW_, camH_);
            grayImg_.allocate(camW_, camH_);
            prevGray_.allocate(camW_, camH_);
            diffImg_.allocate(camW_, camH_);
            edgesImg_.allocate(camW_, camH_);
            threshImg_.allocate(camW_, camH_);
        }
    }
}

void WebcamVis::update(const VisFrame& frame) {
    // -- Interlock : si le pont data_feeds emet activement de la pose,
    // on libere la webcam pour eviter que les deux process se la disputent
    // (macOS donne des frames noires au second client). Le user peut
    // forcer la capture locale en appelant setEnableLocalCapture(true)
    // ET en coupant le worker pose cote Python.
    const bool poseAlive = frame.osc.dataAlive()
        && frame.osc.dataf("pose", "count", -1.0f) >= 0.0f;
    if (poseAlive && cameraOk_) {
        grabber_.close();
        cameraOk_ = false;
        haveFrame_ = false;
        ofLogNotice("WebcamVis") << "pose feed detected — releasing local camera";
    }
    // -- Capture + pipeline OpenCV (mode A) ---------------------------
    if (cameraOk_) {
        grabber_.update();
        if (grabber_.isFrameNew()) {
            colorImg_.setFromPixels(grabber_.getPixels());
            if (mirror_) colorImg_.mirror(false, true);
            grayImg_ = colorImg_;
            // edges via Canny-like (Sobel + threshold)
            edgesImg_ = grayImg_;
            edgesImg_.blurGaussian(3);
            // ofxOpenCv ne wrappe pas Canny directement → on fait
            // une approx : abs(diff) avec un soft-threshold.
            threshImg_ = grayImg_;
            threshImg_.threshold((int)threshold_);
            if (haveFrame_) {
                diffImg_.absDiff(prevGray_, grayImg_);
                diffImg_.threshold(15);
            }
            prevGray_ = grayImg_;
            haveFrame_ = true;
        }
    }

    // -- Lecture du skeleton OSC --------------------------------------
    personCount_ = (int)frame.osc.dataf("pose", "count", 0.0f);
    std::vector<float> skel;
    if (frame.osc.consumeDataPulse("pose", "skel", skel)) {
        // skel = [idx, avg, x0,y0,c0, x1,y1,c1, ...]  (53 floats si idx=0)
        if (skel.size() >= 2 + 17 * 3) {
            skelAvgConf_ = skel[1];
            for (int i = 0; i < 17; ++i) {
                int o = 2 + i * 3;
                skel_[i] = {skel[o], skel[o + 1], skel[o + 2]};
            }
            lastSkelT_ = ofGetElapsedTimef();
        }
    }
}

void WebcamVis::draw(int x, int y, int w, int h) {
    ofPushStyle();
    ofSetColor(255);

    // -- Couche image -------------------------------------------------
    if (cameraOk_ && haveFrame_) {
        switch (mode_) {
            case 1: edgesImg_.draw(x, y, w, h); break;
            case 2: threshImg_.draw(x, y, w, h); break;
            case 3: diffImg_.draw(x, y, w, h);   break;
            case 0:
            default: colorImg_.draw(x, y, w, h); break;
        }
    } else {
        ofSetColor(20);
        ofDrawRectangle(x, y, w, h);
        ofSetColor(120);
        ofDrawBitmapString("no camera — skeleton only", x + 16, y + 24);
    }

    // -- Overlay skeleton --------------------------------------------
    const double now = ofGetElapsedTimef();
    const bool fresh = lastSkelT_ >= 0.0 && (now - lastSkelT_) < 1.0;
    if (!fresh || personCount_ == 0) { ofPopStyle(); return; }

    auto mapX = [&](float xn) { return x + (mirror_ ? (1.f - xn) : xn) * w; };
    auto mapY = [&](float yn) { return y + yn * h; };

    // Bones
    ofSetLineWidth(2.5f);
    for (auto [a, b] : kBones) {
        const auto& A = skel_[a];
        const auto& B = skel_[b];
        if (A.c < 0.2f || B.c < 0.2f) continue;
        float cv = std::min(A.c, B.c);
        ofSetColor(0, 255 * cv, 200 * cv, 255 * skelAlpha_);
        ofDrawLine(mapX(A.x), mapY(A.y), mapX(B.x), mapY(B.y));
    }
    // Joints
    for (int i = 0; i < 17; ++i) {
        const auto& K = skel_[i];
        if (K.c < 0.2f) continue;
        ofSetColor(255, 80, 80, 255 * skelAlpha_);
        ofDrawCircle(mapX(K.x), mapY(K.y), 4.0f + 4.0f * K.c);
    }

    // HUD
    ofSetColor(180, 220);
    ofDrawBitmapString(
        "pose: " + ofToString(personCount_) + "p  conf=" +
            ofToString(skelAvgConf_, 2),
        x + 12, y + h - 12);

    ofPopStyle();
}

} // namespace oscope
