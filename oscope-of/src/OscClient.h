#pragma once

// Client OSC pour le pont sound_algo.
//
// Reçoit sur 127.0.0.1:57122 les messages /sync/* émis par le bridge :
//   /sync/bpm <float>
//   /sync/beat <int>
//   /sync/amp <string voice> <float val>      // 8 voies
//   /sync/rms <float master>
//   /sync/album <string>
//   /sync/melody <string>
//   /sync/synthdef <string>
//
// Envoie sur 127.0.0.1:57121 les messages /control/* compris par sclang
// (kicks, mélodies, FX, etc.).

#include "ofxOsc.h"

#include <string>
#include <unordered_map>
#include <vector>

namespace oscope {

class OscClient {
public:
    void setup(int listenPort, const std::string& sendHost, int sendPort);
    void update();

    // Etat courant (lu par les visualizers).
    float bpm() const { return bpm_; }
    int beat() const { return beat_; }
    float amp(const std::string& voice) const;
    float rms() const { return rms_; }
    const std::string& album() const { return album_; }
    const std::string& melody() const { return melody_; }
    const std::string& synthdef() const { return synthdef_; }

    /// Beat impulse : retourne true une seule fois quand le beat change.
    bool beatPulse();

    /// Helpers d'envoi.
    void sendKick(const std::string& name);
    void sendMelody(const std::string& name);
    void sendAlbum(const std::string& name);
    void sendControl(const std::string& addr, float value);
    void sendControl(const std::string& addr, const std::string& value);

private:
    ofxOscReceiver receiver_;
    ofxOscSender sender_;

    float bpm_ = 120.0f;
    int beat_ = 0;
    int lastBeatPulsed_ = -1;
    float rms_ = 0.0f;
    std::unordered_map<std::string, float> amp_;
    std::string album_;
    std::string melody_;
    std::string synthdef_;
};

} // namespace oscope
