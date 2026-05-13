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

#include <deque>
#include <string>
#include <unordered_map>
#include <vector>

// En complement, ce client recoit aussi les flux /data/<source>/<sub>
// emis par data_feeds/bridge.py. Les arguments numeriques de chaque
// message sont conserves dans un vector accessible via data(source, sub).
// Le dernier evenement est aussi disponible comme "pulse" consommable
// (events de foudre, transactions BTC, posts Bluesky, etc.).

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

    /// Read a /oscope/fx/<name> value (0..1 by convention). Returns
    /// fallback when nothing has been received for that name.
    float fx(const std::string& name, float fallback = 0.0f) const;
    /// True once when /oscope/glitch <amount> arrives, then consumed.
    bool consumeGlitchPulse(float& outAmount);

    /// Helpers d'envoi.
    void sendKick(const std::string& name);
    void sendMelody(const std::string& name);
    void sendAlbum(const std::string& name);
    void sendControl(const std::string& addr, float value);
    void sendControl(const std::string& addr, const std::string& value);

    /// ----- Flux temps reel externes (data_feeds bridge) -----
    /// Acces direct au dernier tuple recu sur /data/<source>/<sub>.
    /// Renvoie vide si rien n'a encore ete recu.
    /// ATTENTION : la reference n'est valide QUE jusqu'au prochain
    /// appel a update(). Ne pas la conserver d'une frame a l'autre.
    const std::vector<float>& data(const std::string& source,
                                   const std::string& sub) const;
    /// Helper : premier arg float du dernier tuple, avec fallback.
    float dataf(const std::string& source, const std::string& sub,
                float fallback = 0.0f, std::size_t index = 0) const;
    /// Heartbeat du pont Python (true si recu il y a < 15 s).
    bool dataAlive() const;

    /// Pulse pour les flux event-based : retourne true UNE fois si un
    /// nouvel evenement /data/<source>/<sub> est arrive depuis le
    /// dernier appel, et remplit `outArgs` avec ses arguments float.
    bool consumeDataPulse(const std::string& source, const std::string& sub,
                          std::vector<float>& outArgs);

private:
    struct DataSlot {
        std::vector<float> last;
        bool pending = false;
    };
    DataSlot* dataSlot(const std::string& key);
    void storeData(const std::string& addr, const ofxOscMessage& m);
    ofxOscReceiver receiver_;
    ofxOscSender sender_;

    float bpm_ = 120.0f;
    int beat_ = 0;
    int lastBeatPulsed_ = -1;
    float rms_ = 0.0f;
    std::unordered_map<std::string, float> amp_;
    std::unordered_map<std::string, float> fx_;
    float pendingGlitchPulse_ = 0.0f;
    bool hasGlitchPulse_ = false;
    std::string album_;
    std::string melody_;
    std::string synthdef_;

    // Flux /data/<source>/<sub>. Cle = "<source>/<sub>".
    std::unordered_map<std::string, DataSlot> data_;
    double lastHeartbeat_ = -1.0;
};

} // namespace oscope
