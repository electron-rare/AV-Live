#pragma once

// Effets demoscene classiques pour Scope4 :
//   - Sine scroller depuis greetings.txt
//   - Starfield 3D (peut remplacer le tunnel)
//   - Copper bars horizontales
//   - Logo bobs (texte qui rebondit / tourne)
//
// Tous les effets sont indépendants et togglables.

#include "ofMain.h"

#include <string>
#include <vector>

namespace oscope {

enum class ScrollerStyle {
    Classic,    // sine wave wobble (par défaut)
    Wavy3D,     // sine + scale per char, effet de respiration 3D
    Rainbow,    // hue cycle large par char (cycle complet sur le texte)
    Mirror,     // classic + reflet vertical en bas avec gradient alpha
    Glitch,     // jitter horizontal aléatoire + couleurs cassées
    Neon,       // double passe : outline cyan + cœur magenta
    Cascade,    // chaque char tombe d'un offset Y, fade lumineux
    Chrome,     // 3 couches superposées effet métallique vertical
    Bouncy,     // chars bondissent sur la baseline avec gravité
    Squashy     // distortion squash & stretch synchro audio
};

class DemoFx {
public:
    void setup(const std::string& greetingsPath);
    void update(float dt);

    /// Scroller bas d'écran. Lit text_, défile, sine wave par char.
    void drawScroller(int W, int H);
    void setScrollerStyle(ScrollerStyle s) { scrollerStyle_ = s; }
    ScrollerStyle scrollerStyle() const { return scrollerStyle_; }
    /// Override le texte du scroller (utilisé par le mode narratif).
    /// Passer "" pour revenir au contenu greetings.txt initial.
    void setText(const std::string& t);

    /// Starfield 3D fullscreen (peut être utilisé en place du tunnel).
    void drawStarfield(int W, int H);

    /// Copper bars : 4-6 bandes horizontales cycliques en haut.
    void drawCopperBars(int W, int H);

    /// Logo bobs : 4-5 caractères qui rebondissent en arc de cercle.
    void drawBobs(int W, int H, const std::string& logo);

    bool& scrollerEnabled()  { return scrollerOn_;  }
    bool& starfieldEnabled() { return starOn_;     }
    bool& copperEnabled()    { return copperOn_;   }
    bool& bobsEnabled()      { return bobsOn_;     }

private:
    // Scroller
    std::string text_;
    std::string baseText_;   // copie du contenu initial (greetings.txt)
    float       scrollX_ = 0.0f;
    bool        scrollerOn_ = true;
    ScrollerStyle scrollerStyle_ = ScrollerStyle::Classic;

    // Starfield
    struct Star { float x, y, z; };
    std::vector<Star> stars_;
    bool starOn_ = false;

    // Copper bars phase
    float copperPhase_ = 0.0f;
    bool  copperOn_   = true;

    // Bobs
    float bobsPhase_ = 0.0f;
    bool  bobsOn_    = true;

    // Time accumulator for steady animation
    float t_ = 0.0f;
};

} // namespace oscope
