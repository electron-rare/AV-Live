// =====================================================================
//  palette/harmonics/presets.scd
//  ~enableHarmony.(\preset) -- 10 presets pour la 2e voix harmonique.
//
//  Presets : \off, \counter, \third, \fifth, \bassline, \arp, \chord,
//            \tranceLayer, \dubBass, \cinematic
//
//  Source unique de ~enableHarmony (engine.scd ne le definit plus).
//  Charge par index.scd. Un seul bloc top-level (compatible .load).
//
//  PREREQUIS : ~melodyNotes, ~reload definis (engine.scd evalue).
// =====================================================================
(
~enableHarmony = { |preset = \off|
    switch (preset,
        \off, {
            ~harmonyAmp = 0;
        },
        // Counter-melody : inverse de la melodie principale
        \counter, {
            ~harmonyInst = \pluck;
            ~harmonyAttack = 0.005; ~harmonyRelease = 0.4;
            ~harmonyCutoff = 4500; ~harmonyAmp = 0.13;
            ~harmonyDur = 0.25;
            ~harmonyNotes = ~melodyNotes.collect { |n|
                if (n > 0) { (132 - n).max(48).min(96) } { 0 };
            };
        },
        // Tierce harmonisee
        \third, {
            ~harmonyInst = \warmPad;
            ~harmonyAttack = 0.3; ~harmonyRelease = 1.2;
            ~harmonyCutoff = 2500; ~harmonyAmp = 0.12;
            ~harmonyDur = 0.25;
            ~harmonyNotes = ~melodyNotes.collect { |n| if(n > 0) {n + 4} {0} };
        },
        // Quinte harmonisee
        \fifth, {
            ~harmonyInst = \warmPad;
            ~harmonyAttack = 0.3; ~harmonyRelease = 1.2;
            ~harmonyCutoff = 2500; ~harmonyAmp = 0.12;
            ~harmonyDur = 0.25;
            ~harmonyNotes = ~melodyNotes.collect { |n| if(n > 0) {n + 7} {0} };
        },
        // Bassline 2 octaves sous la melodie
        \bassline, {
            ~harmonyInst = \subBoom;
            ~harmonyAttack = 0.005; ~harmonyRelease = 0.6;
            ~harmonyAmp = 0.30;
            ~harmonyDur = 0.5;
            ~harmonyNotes = ~melodyNotes.collect { |n|
                if (n > 0) { (n - 24).max(24) } { 0 };
            };
        },
        // Arpege rapide en 1/32 sur les memes notes
        \arp, {
            ~harmonyInst = \pluck;
            ~harmonyAttack = 0.001; ~harmonyRelease = 0.2;
            ~harmonyCutoff = 5500; ~harmonyAmp = 0.13;
            ~harmonyDur = 0.125;
            ~harmonyNotes = ~melodyNotes.collect { |n|
                if (n > 0) { n + 12 } { 0 };
            };
        },
        // Chord stabs (quinte sup avec dur plus lente)
        \chord, {
            ~harmonyInst = \warmPad;
            ~harmonyAttack = 0.05; ~harmonyRelease = 1.5;
            ~harmonyCutoff = 2200; ~harmonyAmp = 0.13;
            ~harmonyDur = 0.5;
            ~harmonyNotes = ~melodyNotes.collect { |n| if(n > 0) {n + 7} {0} };
        },
        // Layer trance : organLead octave +1
        \tranceLayer, {
            ~harmonyInst = \organLead;
            ~harmonyAttack = 0.005; ~harmonyRelease = 0.2;
            ~harmonyCutoff = 5000; ~harmonyAmp = 0.12;
            ~harmonyDur = 0.25;
            ~harmonyNotes = ~melodyNotes.collect { |n| if(n > 0) {n + 12} {0} };
        },
        // Dub bass : sub avec long sustain
        \dubBass, {
            ~harmonyInst = \subBoom;
            ~harmonyAttack = 0.01; ~harmonyRelease = 1.0;
            ~harmonyAmp = 0.32;
            ~harmonyDur = 1.0;
            ~harmonyNotes = ~melodyNotes.collect { |n|
                if (n > 0) { (n - 24).max(24) } { 0 };
            };
        },
        // Cinematic strings layer
        \cinematic, {
            ~harmonyInst = \strings;
            ~harmonyAttack = 0.4; ~harmonyRelease = 1.5;
            ~harmonyCutoff = 3500; ~harmonyAmp = 0.14;
            ~harmonyDur = 0.5;
            ~harmonyNotes = ~melodyNotes.collect { |n| if(n > 0) {n + 7} {0} };
        }
    );
    ~reload.value;
};

"[harmonics/presets] ~enableHarmony pret (10 presets : off counter third fifth bassline arp chord tranceLayer dubBass cinematic)".postln;
)
