#include "OscClient.h"

#include "ofLog.h"
#include "ofUtils.h"

namespace oscope {

namespace {
constexpr const char* kDataPrefix = "/data/";
}


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
        } else if (a.rfind(kDataPrefix, 0) == 0) {
            // /data/heartbeat ou /data/<source>/<sub>
            if (a == "/data/heartbeat") {
                lastHeartbeat_ = ofGetElapsedTimef();
            } else {
                storeData(a, m);
            }
        }
    }
}

void OscClient::storeData(const std::string& addr, const ofxOscMessage& m) {
    // strip "/data/" prefix → key = "source/sub"
    std::string key = addr.substr(6);
    if (key.empty()) return;
    auto& slot = data_[key];
    slot.last.clear();
    slot.last.reserve(m.getNumArgs());
    for (std::size_t i = 0; i < (std::size_t)m.getNumArgs(); ++i) {
        // Les flux poussent surtout des floats ; on tente string→hash
        // pour rester homogene. Les ints sont remontes en float aussi.
        auto t = m.getArgType(i);
        if (t == OFXOSC_TYPE_FLOAT) {
            slot.last.push_back(m.getArgAsFloat(i));
        } else if (t == OFXOSC_TYPE_INT32) {
            slot.last.push_back((float)m.getArgAsInt32(i));
        } else if (t == OFXOSC_TYPE_DOUBLE) {
            slot.last.push_back((float)m.getArgAsDouble(i));
        } else if (t == OFXOSC_TYPE_STRING) {
            // hash djb2 16 bits pour cohérence avec le pont Python
            const auto& s = m.getArgAsString(i);
            std::uint32_t h = 5381;
            for (char c : s) h = ((h << 5) + h + (unsigned char)c) & 0xFFFF;
            slot.last.push_back((float)h);
        }
    }
    slot.pending = true;
}

const std::vector<float>& OscClient::data(const std::string& source,
                                          const std::string& sub) const {
    static const std::vector<float> empty;
    auto it = data_.find(source + "/" + sub);
    return (it == data_.end()) ? empty : it->second.last;
}

float OscClient::dataf(const std::string& source, const std::string& sub,
                       float fallback, std::size_t index) const {
    const auto& v = data(source, sub);
    return (index < v.size()) ? v[index] : fallback;
}

bool OscClient::dataAlive() const {
    return lastHeartbeat_ >= 0.0 &&
           (ofGetElapsedTimef() - lastHeartbeat_) < 15.0f;
}

bool OscClient::consumeDataPulse(const std::string& source,
                                 const std::string& sub,
                                 std::vector<float>& outArgs) {
    auto it = data_.find(source + "/" + sub);
    if (it == data_.end() || !it->second.pending) return false;
    outArgs = it->second.last;
    it->second.pending = false;
    return true;
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
