#pragma once

// Wrapper libusb-1.0 pour l'oscilloscope Hantek 6022BL (Cypress FX2-based).
//
// Références protocolaires :
//   - https://github.com/OpenHantek/OpenHantek6022 (code firmware open-source
//     Cypress FX2 + commandes vendor)
//   - VID 0x04B5 / PID 0x6022 (firmware non chargé) ou 0x602A (variante)
//   - Endpoint bulk IN 0x86 sur l'interface 0, alt setting 1
//
// Important : le 6022BL démarre en "device générique" tant que le firmware
// Cypress n'est pas uploadé. Cette classe détecte ce cas et retourne
// Status::FirmwareNeeded au lieu de tenter un upload (le user doit utiliser
// fxload externe — voir docs/HANTEK_SETUP.md).

#include <atomic>
#include <cstdint>
#include <memory>
#include <string>
#include <thread>

#include "ScopeData.h"

struct libusb_context;
struct libusb_device_handle;

namespace oscope {

enum class HantekStatus {
    Ok,
    NotFound,
    FirmwareNeeded,
    OpenFailed,
    InterfaceClaimFailed,
    AlreadyRunning,
    UsbError
};

enum class HantekGain {
    G_5V    = 0, ///< +/- 5 V (0x01)
    G_2_5V  = 1, ///< +/- 2.5 V (0x02)
    G_1V    = 2, ///< +/- 1 V (0x05)
    G_500mV = 3, ///< +/- 500 mV (0x0a)
    G_250mV = 4  ///< +/- 250 mV (0x14)
};

class HantekDevice {
public:
    HantekDevice();
    ~HantekDevice();

    HantekDevice(const HantekDevice&) = delete;
    HantekDevice& operator=(const HantekDevice&) = delete;

    /// Ouvre le device, claim l'interface, configure sample rate / gains.
    /// Démarre le thread bulk-transfer et alimente le ringbuffer.
    HantekStatus start();

    /// Stoppe le thread, libère l'interface, ferme libusb.
    void stop();

    /// Sample rate desired (Hz). Codes valides : 1e6, 2e6, 4e6, 8e6, 16e6,
    /// 24e6, 48e6 (24 et 48 MS/s ne sont disponibles qu'avec un seul canal
    /// actif sur le firmware OpenHantek6022).
    void setSampleRate(uint32_t hz);

    /// Gain par canal (1 ou 2).
    void setGain(int channel, HantekGain gain);

    /// Accesseur vers le ringbuffer partagé.
    ScopeRing& ring() { return ring_; }

    /// Statut courant (Ok ou dernier code d'erreur).
    HantekStatus status() const { return status_.load(); }

    /// Description humaine du dernier statut.
    std::string statusString() const;

    /// Indique si un firmware doit être chargé (renvoyé par start()).
    bool firmwareNeeded() const { return status_.load() == HantekStatus::FirmwareNeeded; }

private:
    void streamLoop();
    bool sendVendorControl(uint8_t request, uint16_t value, uint16_t index,
                           const uint8_t* data, uint16_t length);
    bool configureDevice();

    libusb_context* ctx_;
    libusb_device_handle* handle_;
    std::thread worker_;
    std::atomic<bool> running_;
    std::atomic<HantekStatus> status_;
    std::atomic<uint32_t> sampleRateHz_;
    std::atomic<int> gainCh1_;
    std::atomic<int> gainCh2_;
    ScopeRing ring_;
};

} // namespace oscope
