#include "OscClient.h"

#include "ofLog.h"

namespace oscope {

void OscClient::setup(int listenPort, const std::string& sendHost, int sendPort) {
    receiver_.setup(listenPort);
    sender_.setup(sendHost, sendPort);
    // Pré-init des 8 voies connues.
    for (const auto& v : {"kick", "hat", "snare", "clap", "perc",
                          "melody", "acid", "harmony"}) {
        amp_[v] = 0.0f;
    }
    ofLogNotice("OscClient") << "listen :" << listenPort
                             << " send -> " << sendHost << ":" << sendPort;
}

void OscClient::update() {
    while (receiver_.hasWaitingMessages()) {
        ofxOscMessage m;
        receiver_.getNextMessage(m);
        const std::string& a = m.getAddress();

        if (a == "/sync/bpm" && m.getNumArgs() >= 1) {
            bpm_ = m.getArgAsFloat(0);
        } else if (a == "/sync/beat" && m.getNumArgs() >= 1) {
            beat_ = m.getArgAsInt32(0);
        } else if (a == "/sync/amp" && m.getNumArgs() >= 2) {
            amp_[m.getArgAsString(0)] = m.getArgAsFloat(1);
        } else if (a == "/sync/rms" && m.getNumArgs() >= 1) {
            rms_ = m.getArgAsFloat(0);
        } else if (a == "/sync/album" && m.getNumArgs() >= 1) {
            album_ = m.getArgAsString(0);
        } else if (a == "/sync/melody" && m.getNumArgs() >= 1) {
            melody_ = m.getArgAsString(0);
        } else if (a == "/sync/synthdef" && m.getNumArgs() >= 1) {
            synthdef_ = m.getArgAsString(0);
        } else if (a.rfind("/oscope/fx/", 0) == 0 && m.getNumArgs() >= 1) {
            // /oscope/fx/<name> <float>
            fx_[a.substr(11)] = m.getArgAsFloat(0);
        } else if (a == "/oscope/glitch" && m.getNumArgs() >= 1) {
            pendingGlitchPulse_ = m.getArgAsFloat(0);
            hasGlitchPulse_ = true;
        }
    }
}

float OscClient::fx(const std::string& name, float fallback) const {
    auto it = fx_.find(name);
    return (it == fx_.end()) ? fallback : it->second;
}

bool OscClient::consumeGlitchPulse(float& outAmount) {
    if (!hasGlitchPulse_) return false;
    outAmount = pendingGlitchPulse_;
    hasGlitchPulse_ = false;
    return true;
}

float OscClient::amp(const std::string& voice) const {
    auto it = amp_.find(voice);
    return (it == amp_.end()) ? 0.0f : it->second;
}

bool OscClient::beatPulse() {
    if (beat_ != lastBeatPulsed_) {
        lastBeatPulsed_ = beat_;
        return true;
    }
    return false;
}

void OscClient::sendKick(const std::string& name) {
    sendControl("/control/kk", name);
}

void OscClient::sendMelody(const std::string& name) {
    sendControl("/control/setMelody", name);
}

void OscClient::sendAlbum(const std::string& name) {
    sendControl("/control/setAlbum", name);
}

void OscClient::sendControl(const std::string& addr, float value) {
    ofxOscMessage m;
    m.setAddress(addr);
    m.addFloatArg(value);
    sender_.sendMessage(m, false);
}

void OscClient::sendControl(const std::string& addr, const std::string& value) {
    ofxOscMessage m;
    m.setAddress(addr);
    m.addStringArg(value);
    sender_.sendMessage(m, false);
}

} // namespace oscope
