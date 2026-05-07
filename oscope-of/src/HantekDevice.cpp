#include "HantekDevice.h"

#include <libusb.h>

#include <chrono>
#include <cstring>
#include <vector>

#include "ofLog.h"

namespace oscope {

namespace {

// Identifiants USB du Hantek 6022BL.
// 0x04B5 / 0x6022 : appareil avec firmware OEM, ou aucun firmware (énumération
//                   minimale, pas de bulk endpoint actif).
// 0x04B5 / 0x602A : appareil avec firmware OpenHantek6022 chargé.
constexpr uint16_t kVendorId          = 0x04B5;
constexpr uint16_t kProductIdRaw      = 0x6022;
constexpr uint16_t kProductIdFirmware = 0x602A;

constexpr int kInterface       = 0;
constexpr int kAltSetting      = 0;  // alt 0 = bulk EP 0x86 (firmware OpenHantek6022)
constexpr unsigned char kEpIn  = 0x86;

// Vendor requests OpenHantek6022.
constexpr uint8_t kReqSetSampleRate = 0xE2;
constexpr uint8_t kReqSetCh1Gain    = 0xE0;
constexpr uint8_t kReqSetCh2Gain    = 0xE1;
constexpr uint8_t kReqSetNumChannels= 0xE4;

// Codes de gain (registre du FX2).
uint8_t gainCode(HantekGain g) {
    switch (g) {
        case HantekGain::G_5V:    return 0x01;
        case HantekGain::G_2_5V:  return 0x02;
        case HantekGain::G_1V:    return 0x05;
        case HantekGain::G_500mV: return 0x0a;
        case HantekGain::G_250mV: return 0x14;
    }
    return 0x05;
}

// Code de sample rate (cf. firmware OpenHantek6022).
uint8_t sampleRateCode(uint32_t hz) {
    if (hz >= 48000000) return 48;
    if (hz >= 24000000) return 30; // dual-channel max ~16 MS/s, 30=24M single
    if (hz >= 16000000) return 16;
    if (hz >=  8000000) return  8;
    if (hz >=  4000000) return  4;
    if (hz >=  2000000) return  2;
    return 1;
}

constexpr int kBulkTimeoutMs = 200;
constexpr int kBulkXferBytes = 8192; // 4096 samples par canal (2 canaux entrelacés)

} // namespace

HantekDevice::HantekDevice()
    : ctx_(nullptr), handle_(nullptr), running_(false),
      status_(HantekStatus::NotFound),
      sampleRateHz_(8000000),
      gainCh1_(static_cast<int>(HantekGain::G_1V)),
      gainCh2_(static_cast<int>(HantekGain::G_1V)) {}

HantekDevice::~HantekDevice() {
    stop();
}

HantekStatus HantekDevice::start() {
    if (running_.load()) {
        status_.store(HantekStatus::AlreadyRunning);
        return HantekStatus::AlreadyRunning;
    }

    int rc = libusb_init(&ctx_);
    if (rc != 0) {
        ofLogError("HantekDevice") << "libusb_init failed: " << libusb_error_name(rc);
        status_.store(HantekStatus::UsbError);
        return HantekStatus::UsbError;
    }

    // Recherche prioritaire du device avec firmware chargé.
    handle_ = libusb_open_device_with_vid_pid(ctx_, kVendorId, kProductIdFirmware);
    if (handle_ == nullptr) {
        // Fallback : device sans firmware.
        handle_ = libusb_open_device_with_vid_pid(ctx_, kVendorId, kProductIdRaw);
        if (handle_ != nullptr) {
            ofLogWarning("HantekDevice")
                << "Hantek 6022BL trouvé MAIS firmware non chargé (PID 0x6022). "
                << "Charger le firmware OpenHantek6022 via fxload, puis relancer. "
                << "Voir docs/HANTEK_SETUP.md.";
            libusb_close(handle_);
            handle_ = nullptr;
            libusb_exit(ctx_);
            ctx_ = nullptr;
            status_.store(HantekStatus::FirmwareNeeded);
            return HantekStatus::FirmwareNeeded;
        }
        ofLogError("HantekDevice") << "Aucun Hantek 6022BL détecté.";
        libusb_exit(ctx_);
        ctx_ = nullptr;
        status_.store(HantekStatus::NotFound);
        return HantekStatus::NotFound;
    }

    // Sur macOS, AppleUSBHostLegacyClient claim l'interface 0 par defaut
    // pour les devices vendor-specific. On force un re-configure (0->1) pour
    // detacher le client legacy, puis reset, puis claim.
    libusb_set_auto_detach_kernel_driver(handle_, 1);
    (void)libusb_detach_kernel_driver(handle_, kInterface);
    (void)libusb_set_configuration(handle_, 0);

    (void)libusb_set_configuration(handle_, 1);

    rc = libusb_claim_interface(handle_, kInterface);
    if (rc != 0) {
        ofLogError("HantekDevice") << "claim_interface failed: " << libusb_error_name(rc);
        libusb_close(handle_);
        handle_ = nullptr;
        libusb_exit(ctx_);
        ctx_ = nullptr;
        status_.store(HantekStatus::InterfaceClaimFailed);
        return HantekStatus::InterfaceClaimFailed;
    }

    rc = libusb_set_interface_alt_setting(handle_, kInterface, kAltSetting);
    ofLogNotice("HantekDevice") << "set_alt_setting(" << kInterface << ", " << kAltSetting
        << ") = " << rc << " (" << libusb_error_name(rc) << ")";
    if (rc != 0) {
        ofLogWarning("HantekDevice") << "alt_setting failed (continuing)";
    }
    libusb_clear_halt(handle_, kEpIn);

    if (!configureDevice()) {
        libusb_release_interface(handle_, kInterface);
        libusb_close(handle_);
        handle_ = nullptr;
        libusb_exit(ctx_);
        ctx_ = nullptr;
        status_.store(HantekStatus::UsbError);
        return HantekStatus::UsbError;
    }

    running_.store(true);
    status_.store(HantekStatus::Ok);
    worker_ = std::thread([this] { streamLoop(); });
    return HantekStatus::Ok;
}

void HantekDevice::stop() {
    running_.store(false);
    if (worker_.joinable()) worker_.join();
    if (handle_ != nullptr) {
        libusb_release_interface(handle_, kInterface);
        libusb_close(handle_);
        handle_ = nullptr;
    }
    if (ctx_ != nullptr) {
        libusb_exit(ctx_);
        ctx_ = nullptr;
    }
}

void HantekDevice::setSampleRate(uint32_t hz) {
    sampleRateHz_.store(hz);
    if (handle_ != nullptr && running_.load()) {
        // Le FX2 (firmware OpenHantek6022) attend la séquence : stop (0xE3=0)
        // → set sample rate (0xE2) → start (0xE3=1). Sans le re-start, le
        // bulk endpoint cesse d'émettre et le stream se fige.
        const uint8_t stopTrig  = 0x00;
        const uint8_t code      = sampleRateCode(hz);
        const uint8_t startTrig = 0x01;
        sendVendorControl(0xE3, 0, 0, &stopTrig, 1);
        sendVendorControl(kReqSetSampleRate, 0, 0, &code, 1);
        sendVendorControl(0xE3, 0, 0, &startTrig, 1);
    }
}

void HantekDevice::setGain(int channel, HantekGain gain) {
    const uint8_t code = gainCode(gain);
    if (channel == 1) {
        gainCh1_.store(static_cast<int>(gain));
        if (handle_) sendVendorControl(kReqSetCh1Gain, 0, 0, &code, 1);
    } else if (channel == 2) {
        gainCh2_.store(static_cast<int>(gain));
        if (handle_) sendVendorControl(kReqSetCh2Gain, 0, 0, &code, 1);
    }
}

bool HantekDevice::sendVendorControl(uint8_t request, uint16_t value,
                                     uint16_t index, const uint8_t* data,
                                     uint16_t length) {
    const uint8_t bmRequestType =
        LIBUSB_REQUEST_TYPE_VENDOR | LIBUSB_RECIPIENT_DEVICE | LIBUSB_ENDPOINT_OUT;
    int rc = libusb_control_transfer(handle_, bmRequestType, request, value, index,
                                     const_cast<uint8_t*>(data), length, 1000);
    if (rc < 0) {
        ofLogError("HantekDevice") << "control_transfer 0x" << std::hex << int(request)
                                   << " failed: " << libusb_error_name(rc);
        return false;
    }
    return true;
}

bool HantekDevice::configureDevice() {
    const uint8_t numChannels = 2;
    if (!sendVendorControl(kReqSetNumChannels, 0, 0, &numChannels, 1)) return false;
    const uint8_t srCode = sampleRateCode(sampleRateHz_.load());
    if (!sendVendorControl(kReqSetSampleRate, 0, 0, &srCode, 1)) return false;
    const uint8_t g1 = gainCode(static_cast<HantekGain>(gainCh1_.load()));
    if (!sendVendorControl(kReqSetCh1Gain, 0, 0, &g1, 1)) return false;
    const uint8_t g2 = gainCode(static_cast<HantekGain>(gainCh2_.load()));
    if (!sendVendorControl(kReqSetCh2Gain, 0, 0, &g2, 1)) return false;
    // E3 = trigger / start sampling (firmware fx2lafw / OpenHantek6022)
    const uint8_t startTrig = 0x01;
    if (!sendVendorControl(0xE3, 0, 0, &startTrig, 1)) {
        ofLogWarning("HantekDevice") << "vendor 0xE3 (start) failed (continuing)";
    }
    ofLogNotice("HantekDevice") << "configureDevice: numCh=2 sr=" << (int)srCode
        << " g1=" << (int)g1 << " g2=" << (int)g2 << " trig=0x01";
    return true;
}

void HantekDevice::streamLoop() {
    std::vector<uint8_t> raw(kBulkXferBytes);
    std::vector<float> ch1, ch2;
    ch1.reserve(kBulkXferBytes / 2);
    ch2.reserve(kBulkXferBytes / 2);

    while (running_.load()) {
        int actual = 0;
        int rc = libusb_bulk_transfer(handle_, kEpIn, raw.data(),
                                      static_cast<int>(raw.size()),
                                      &actual, kBulkTimeoutMs);
        if (rc == LIBUSB_ERROR_TIMEOUT) {
            continue;
        }
        if (rc != 0) {
            ofLogWarning("HantekDevice") << "bulk_transfer: " << libusb_error_name(rc);
            std::this_thread::sleep_for(std::chrono::milliseconds(50));
            continue;
        }

        static std::atomic<uint64_t> totalBytes{0};
        static auto lastLog = std::chrono::steady_clock::now();
        totalBytes += actual;
        auto now = std::chrono::steady_clock::now();
        if (std::chrono::duration_cast<std::chrono::seconds>(now - lastLog).count() >= 2) {
            ofLogNotice("HantekDevice") << "stream " << totalBytes.load() << " bytes received";
            lastLog = now;
        }

        // Format OpenHantek6022 : octets entrelacés [CH1, CH2, CH1, CH2, ...].
        // Chaque échantillon est un uint8_t centré autour de 128 (offset binary).
        const std::size_t pairs = static_cast<std::size_t>(actual) / 2;
        ch1.resize(pairs);
        ch2.resize(pairs);
        for (std::size_t i = 0; i < pairs; ++i) {
            const uint8_t a = raw[2 * i];
            const uint8_t b = raw[2 * i + 1];
            ch1[i] = (static_cast<float>(a) - 128.0f) / 128.0f;
            ch2[i] = (static_cast<float>(b) - 128.0f) / 128.0f;
        }
        ring_.push(ch1.data(), ch2.data(), pairs);
    }
}

std::string HantekDevice::statusString() const {
    switch (status_.load()) {
        case HantekStatus::Ok: return "OK";
        case HantekStatus::NotFound: return "Aucun Hantek 6022BL detecte";
        case HantekStatus::FirmwareNeeded: return "Firmware Cypress non charge (voir docs/HANTEK_SETUP.md)";
        case HantekStatus::OpenFailed: return "libusb_open echec";
        case HantekStatus::InterfaceClaimFailed: return "claim_interface echec";
        case HantekStatus::AlreadyRunning: return "deja en cours";
        case HantekStatus::UsbError: return "erreur USB";
    }
    return "?";
}

} // namespace oscope
