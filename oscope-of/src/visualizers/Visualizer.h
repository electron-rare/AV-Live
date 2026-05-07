#pragma once

// Interface abstraite pour les 3 modes de visualisation.

#include "../OscClient.h"
#include "../ScopeData.h"

#include <vector>

namespace oscope {

struct VisFrame {
    const std::vector<float>& ch1;
    const std::vector<float>& ch2;
    OscClient& osc;
};

class Visualizer {
public:
    virtual ~Visualizer() = default;
    virtual void setup(int w, int h) = 0;
    virtual void update(const VisFrame& frame) = 0;
    virtual void draw(int x, int y, int w, int h) = 0;
    virtual void reloadShaders() {}
};

} // namespace oscope
