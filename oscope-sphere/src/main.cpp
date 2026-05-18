// oscope-sphere — window bootstrap. GL 3.2 core profile, MSAA 8x.
#include "ofMain.h"
#include "ofApp.h"

int main() {
    ofGLFWWindowSettings settings;
    settings.setGLVersion(3, 2);
    settings.setSize(1920, 1080);
    settings.numSamples = 8;
    settings.windowMode = OF_WINDOW;
    settings.title = "oscope-sphere";

    auto window = ofCreateWindow(settings);
    ofRunApp(window, std::make_shared<ofApp>());
    ofRunMainLoop();
    return 0;
}
