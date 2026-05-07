// oscope-of — main entry point.
// Fenêtre 1920x1080 avec MSAA 8x, OpenGL 3.2 core profile pour les shaders modernes.

#include "ofMain.h"
#include "ofApp.h"

int main() {
    ofGLFWWindowSettings settings;
    settings.setGLVersion(3, 2);
    settings.setSize(1920, 1080);
    settings.numSamples = 8;
    settings.windowMode = OF_WINDOW;
    settings.title = "oscope-of";

    auto window = ofCreateWindow(settings);
    ofRunApp(window, std::make_shared<ofApp>());
    ofRunMainLoop();
    return 0;
}
