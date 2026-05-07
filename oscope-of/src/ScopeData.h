#pragma once

// Structure partagée entre le thread USB Hantek et le thread principal OF.
// Ringbuffer SPSC (single-producer / single-consumer) lock-free basé sur
// std::atomic. Le producteur est le thread bulk-transfer libusb, le consommateur
// est ofApp::update().

#include <array>
#include <atomic>
#include <cstddef>
#include <cstdint>
#include <vector>

namespace oscope {

// Capacité du ringbuffer en échantillons par canal. Doit être une puissance de 2
// pour permettre le masquage modulo via (idx & (kCapacity - 1)).
static constexpr std::size_t kRingCapacity = 1u << 18; // 262144 samples

/// Buffer SPSC partagé pour les échantillons CH1/CH2 normalisés [-1, 1].
class ScopeRing {
public:
    ScopeRing() : write_(0), read_(0) {
        ch1_.resize(kRingCapacity, 0.0f);
        ch2_.resize(kRingCapacity, 0.0f);
    }

    /// Producteur : écrit n échantillons. Si le buffer est plein, écrase
    /// les plus anciens (overwrite policy, on préfère perdre du passé que
    /// bloquer le thread USB).
    void push(const float* ch1, const float* ch2, std::size_t n) {
        const std::size_t mask = kRingCapacity - 1;
        std::size_t w = write_.load(std::memory_order_relaxed);
        for (std::size_t i = 0; i < n; ++i) {
            ch1_[(w + i) & mask] = ch1[i];
            ch2_[(w + i) & mask] = ch2[i];
        }
        write_.store(w + n, std::memory_order_release);
    }

    /// Consommateur : lit jusqu'à `nrequested` échantillons les plus récents.
    /// Retourne le nombre effectivement copié.
    std::size_t readLatest(std::vector<float>& outCh1,
                           std::vector<float>& outCh2,
                           std::size_t nrequested) {
        const std::size_t mask = kRingCapacity - 1;
        const std::size_t w = write_.load(std::memory_order_acquire);
        const std::size_t available = (w >= nrequested) ? nrequested : w;
        outCh1.resize(available);
        outCh2.resize(available);
        const std::size_t start = w - available;
        for (std::size_t i = 0; i < available; ++i) {
            outCh1[i] = ch1_[(start + i) & mask];
            outCh2[i] = ch2_[(start + i) & mask];
        }
        read_.store(w, std::memory_order_release);
        return available;
    }

    std::size_t writeIndex() const { return write_.load(std::memory_order_acquire); }

private:
    std::vector<float> ch1_;
    std::vector<float> ch2_;
    std::atomic<std::size_t> write_;
    std::atomic<std::size_t> read_;
};

} // namespace oscope
