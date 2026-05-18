#include "ofApp.h"

void ofApp::setup() {
    ofSetFrameRate(60);
    ofBackground(6, 6, 10);
}

void ofApp::update() {}

void ofApp::draw() {
    ofSetColor(230);
    ofDrawBitmapString("oscope-sphere skeleton", 16, 24);
}
