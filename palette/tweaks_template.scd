// =====================================================================
//  tweaks_template.scd  --  Tweaks live communs charges par toutes les tracks
//
//  Ne PAS evaluer le fichier en bloc. Cmd+Entree sur une ligne au choix
//  pendant qu'une track tourne.
// =====================================================================


// =====================================================================
//  TWEAKS LIVE RICHES -- Cmd+Entree sur une ligne pendant la track
// =====================================================================

// === STOP / CONTROLE ============================================
(~track.stop;)

// === MUTE INSTANTANE par voix ===================================
(~kickAmp = 0;     ~reload.value;)
(~kickAmp = 0.5;   ~reload.value;)
(~hatAmp = 0;      ~reload.value;)
(~hatAmp = 0.18;   ~reload.value;)
(~snareAmp = 0;    ~reload.value;)
(~snareAmp = 0.5;  ~reload.value;)
(~clapAmp = 0;     ~reload.value;)
(~clapAmp = 0.35;  ~reload.value;)
(~percAmp = 0;     ~reload.value;)
(~percAmp = 0.25;  ~reload.value;)
(~melodyAmp = 0;   ~reload.value;)
(~melodyAmp = 0.18;~reload.value;)
(~harmonyAmp = 0;  ~reload.value;)
(~harmonyAmp = 0.14;~reload.value;)

// === SOLO une piste (mute les autres) ===========================
(~kickAmp=0;~hatAmp=0;~clapAmp=0;~melodyAmp=0;~harmonyAmp=0;~snareAmp=0.5;~reload.value;)  // solo snare
(~kickAmp=0;~hatAmp=0;~clapAmp=0;~snareAmp=0;~harmonyAmp=0;~melodyAmp=0.2;~reload.value;)  // solo melody
(~kickAmp=0.5;~hatAmp=0;~snareAmp=0;~clapAmp=0;~melodyAmp=0;~harmonyAmp=0;~reload.value;)  // solo kick

// === HARMONY -- 2e voix melodique ==============================
(~enableHarmony.(\off);)              // mute harmony
(~enableHarmony.(\third);)            // tierce harmonisee
(~enableHarmony.(\fifth);)            // quinte harmonisee
(~enableHarmony.(\counter);)          // contre-melodie inversee
(~enableHarmony.(\bassline);)         // bass 2 octaves -2
(~enableHarmony.(\dubBass);)          // dub bass long sustain
(~enableHarmony.(\arp);)              // arpege octave +1 en 1/32
(~enableHarmony.(\chord);)            // chord pad sustained
(~enableHarmony.(\tranceLayer);)      // organ +1 octave
(~enableHarmony.(\cinematic);)        // strings layer

// === SWITCH SYNTH MELODIE =======================================
(~melodyInst = \lead;       ~reload.value;)
(~melodyInst = \pad;        ~reload.value;)
(~melodyInst = \warmPad;    ~reload.value;)
(~melodyInst = \pluck;      ~reload.value;)
(~melodyInst = \fmBell;     ~reload.value;)
(~melodyInst = \stab;       ~reload.value;)
(~melodyInst = \saw3;       ~reload.value;)
(~melodyInst = \squareLead; ~reload.value;)
(~melodyInst = \fmLead;     ~reload.value;)
(~melodyInst = \organLead;  ~reload.value;)
(~melodyInst = \hardLead;   ~reload.value;)
(~melodyInst = \strings;    ~reload.value;)
(~melodyInst = \choir;      ~reload.value;)
(~melodyInst = \fmBass;     ~reload.value;)
(~melodyInst = \subBoom;    ~reload.value;)
(~melodyInst = \handpan;    ~reload.value;)
(~melodyInst = \flute;      ~reload.value;)
(~melodyInst = \drone;      ~reload.value;)
(~melodyInst = \koto;       ~reload.value;)
(~melodyInst = \erhu;       ~reload.value;)
(~melodyInst = \pipa;       ~reload.value;)
(~melodyInst = \growl;      ~reload.value;)

// === CUTOFF / RESONANCE =========================================
(~melodyCutoff = 400;  ~reload.value;)
(~melodyCutoff = 1200; ~reload.value;)
(~melodyCutoff = 3000; ~reload.value;)
(~melodyCutoff = 6000; ~reload.value;)
(~melodyRq = 0.05; ~reload.value;)   // resonance EXTREME (fmBell/growl)
(~melodyRq = 0.2;  ~reload.value;)
(~melodyRq = 0.5;  ~reload.value;)

// === DRIVE / VOLUME =============================================
(~melodyDrive = 1.0; ~reload.value;)
(~melodyDrive = 2.5; ~reload.value;)
(~melodyDrive = 5.0; ~reload.value;)
(~melodyBoost = 1.0; ~reload.value;)
(~melodyBoost = 2.5; ~reload.value;)

// === SIDECHAIN PUMP =============================================
(~acidScAmt = 0;    ~reload.value;)   // acid sans duck
(~acidScAmt = 0.7;  ~reload.value;)   // acid normal
(~acidScAmt = 0.95; ~reload.value;)   // acid pump fort
(~leadScAmt = 0;    ~reload.value;)
(~leadScAmt = 0.5;  ~reload.value;)
(~leadScAmt = 0.9;  ~reload.value;)
(~kickScShape = 0.08; ~reload.value;)  // pump court
(~kickScShape = 0.18; ~reload.value;)  // normal
(~kickScShape = 0.35; ~reload.value;)  // pump long french touch

// === KICK CHARACTER =============================================
(~kickFreq=42; ~kickPitchAmt=2.0; ~kickDecay=0.5; ~kickDrive=1.0; ~kickClick=0.05; ~reload.value;) // T5 sub
(~kickFreq=55; ~kickPitchAmt=3.0; ~kickDecay=0.32;~kickDrive=1.3; ~kickClick=0.20; ~reload.value;) // T1 rond
(~kickFreq=65; ~kickPitchAmt=4.0; ~kickDecay=0.18;~kickDrive=1.8; ~kickClick=0.45; ~reload.value;) // T2 claquant
(~kickFreq=48; ~kickPitchAmt=2.5; ~kickDecay=0.6; ~kickDrive=1.2; ~kickClick=0.08; ~reload.value;) // T3 boomy
(~kickFreq=60; ~kickPitchAmt=5.0; ~kickDecay=0.28;~kickDrive=3.5; ~kickClick=0.30; ~reload.value;) // T4 distordu
(~kickFreq=70; ~kickPitchAmt=3.5; ~kickDecay=0.22;~kickDrive=2.0; ~kickClick=0.35; ~reload.value;) // T6 punchy

// === DUBSTEP WOBBLE (si melodyInst = fmBell ou growl) ===========
(~melodyWobbleRate = 2;  ~reload.value;)   // 1/4
(~melodyWobbleRate = 4;  ~reload.value;)   // 1/8
(~melodyWobbleRate = 8;  ~reload.value;)   // 1/16
(~melodyWobbleRate = 16; ~reload.value;)   // 1/32
(~melodyWobbleShape = 0; ~reload.value;)   // smooth
(~melodyWobbleShape = 1; ~reload.value;)   // chop square
(~melodyWobbleDepth = 1000;~reload.value;) // sub
(~melodyWobbleDepth = 2500;~reload.value;) // normal
(~melodyWobbleDepth = 4000;~reload.value;) // EXTREME
(~melodySubAmt = 0.3; ~reload.value;)      // sub leger
(~melodySubAmt = 0.7; ~reload.value;)      // sub normal
(~melodySubAmt = 1.0; ~reload.value;)      // sub MASSIF

// === ACID 303 ====================================================
(~acidCutoff = 200;  ~reload.value;)
(~acidCutoff = 800;  ~reload.value;)
(~acidCutoff = 2000; ~reload.value;)
(~acidRq = 0.05; ~reload.value;)        // resonance acide EXTREME
(~acidRq = 0.15; ~reload.value;)
(~acidDrive = 1.0; ~reload.value;)
(~acidDrive = 4.5; ~reload.value;)

// === PATTERNS RYTHME (kick) =====================================
(~kickSteps = [1,0,0,0, 1,0,0,0, 1,0,0,0, 1,0,0,0]; ~reload.value;)  // 4/4
(~kickSteps = [1,0,0,0, 0,0,0,0, 1,0,0,0, 0,0,0,0]; ~reload.value;)  // half-time
(~kickSteps = [1,0,1,0, 1,0,1,0, 1,0,1,0, 1,0,1,0]; ~reload.value;)  // gabber double
(~kickSteps = [1,0,0,1, 0,0,1,0, 1,0,0,0, 0,1,0,0]; ~reload.value;)  // syncope
(~kickSteps = [1,0,0,0, 0,0,1,0, 0,0,1,0, 1,0,0,0]; ~reload.value;)  // amen
(~kickSteps = [0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0]; ~reload.value;)  // mute

// === PATTERNS HAT ================================================
(~hatSteps = [0,0,1,0, 0,0,1,0, 0,0,1,0, 0,0,1,0]; ~reload.value;)   // offbeat
(~hatSteps = [1,1,1,1, 1,1,1,1, 1,1,1,1, 1,1,1,1]; ~reload.value;)   // 16ths
(~hatSteps = [1,0,1,1, 0,1,1,0, 1,0,1,1, 0,1,1,0]; ~reload.value;)   // trap triplets
(~hatSteps = [0,1,0,1, 1,1,0,1, 0,1,0,1, 1,1,0,1]; ~reload.value;)   // breakbeat

// === MELODIES (charger une mélodie sans changer le timbre) =======
(~melodyNotes = ~genMelody.(0.55, ~scaleMinorPent); ~reload.value;)
(~melodyNotes = ~genMelody.(0.7,  ~scaleMinor);     ~reload.value;)
(~melodyNotes = ~genMelody.(0.5,  ~scaleDorian);    ~reload.value;)
(~melodyNotes = ~genMelody.(0.45, ~scalePhrygian);  ~reload.value;)
(~melodyNotes = ~genMelody.(0.5,  ~scaleHarmonicMin);~reload.value;)
(~melodyNotes = ~genMelody.(0.6,  ~scaleJapanese);  ~reload.value;)
(~melodyNotes = ~mutate.(~melodyNotes, 0.3);  ~reload.value;)
(~melodyNotes = ~transpose.(~melodyNotes, 5); ~reload.value;)  // +4te
(~melodyNotes = ~transpose.(~melodyNotes, -3);~reload.value;)  // -tierce min
(~melodyNotes = ~transpose.(~melodyNotes, 12);~reload.value;)  // +1 octave
(~melodyNotes = ~retrograde.(~melodyNotes);   ~reload.value;)
(~melodyNotes = ~octavate.(~melodyNotes, 0.4);~reload.value;)
(~melodyNotes = ~densify.(~melodyNotes, 0.3); ~reload.value;)
(~melodyNotes = ~sparsify.(~melodyNotes, 0.4);~reload.value;)

// === TEMPO =======================================================
(TempoClock.default.tempo = 100/60;)
(TempoClock.default.tempo = 120/60;)
(TempoClock.default.tempo = 132/60;)
(TempoClock.default.tempo = 145/60;)
(TempoClock.default.tempo = 174/60;)
(TempoClock.default.tempo = (~bpm * 0.95)/60;)  // slow down 5%
(TempoClock.default.tempo = (~bpm * 1.05)/60;)  // speed up 5%

// === FX ONESHOTS =================================================
(Synth(\impact, [\freq, 45, \decay, 1.5, \amp, 0.5]);)
(Synth(\impact, [\freq, 30, \decay, 3.0, \amp, 0.7]);)        // gros boom
(Synth(\riser, [\dur, 4,  \startCutoff, 200, \endCutoff, 8000,  \amp, 0.25]);)
(Synth(\riser, [\dur, 8,  \startCutoff, 300, \endCutoff, 10000, \amp, 0.30]);)
(Synth(\riser, [\dur, 16, \startCutoff, 400, \endCutoff, 12000, \amp, 0.35]);) // long
(Synth(\sweep, [\dur, 4,  \startCutoff, 8000,\endCutoff, 200, \amp, 0.25]);)   // descend
(Synth(\sweep, [\dur, 8,  \startCutoff, 12000,\endCutoff,200, \amp, 0.35]);)   // long descend
(Synth(\crash, [\decay, 1.5, \amp, 0.3]);)
(Synth(\crash, [\decay, 4.0, \amp, 0.4]);)                    // crash long
(Synth(\gong,  [\freq, 40, \decay, 8, \amp, 0.6]);)           // gong profond
(Synth(\gong,  [\freq, 80, \decay, 5, \amp, 0.4]);)           // gong haut

// === FILLS et ROLLS =============================================
(~snareFill.(8,  1, 0.3, 0.5);)        // 8 hits 1s
(~snareFill.(16, 2, 0.2, 0.55);)       // 16 hits 2s accelerando
(~snareFill.(32, 2, 0.15, 0.6);)       // 32 hits frenetic
(~tomFill.value;)                        // descente 4 toms
(8.do { Synth(\hat, [\amp, 0.15, \decay, 0.03]); 0.075.wait };)  // hat roll

// === VINYL TEXTURE (continu) ====================================
(~vinyl !? { ~vinyl.free }; ~vinyl = Synth(\vinyl, [\amp, 0.08]); "vinyl ON".postln;)
(~vinyl !? { ~vinyl.free; ~vinyl = nil }; "vinyl OFF".postln;)

// === FILTER SWEEP AUTOMATIQUE (continu, infini) =================
(
~filterSweep !? { ~filterSweep.stop };
~filterSweep = Routine({
    inf.do { |k|
        ~melodyCutoff = 200 + ((k / 32 * 2 * pi).sin.abs * 4500);
        ~reload.value;
        0.25.wait;
    };
}).play;
"filter sweep ON".postln;
)
( ~filterSweep !? { ~filterSweep.stop }; "filter sweep OFF".postln; )

// === DROP (cut tout sauf melody pendant 2s puis relance) =========
(
Routine({
    var oldKick = ~kickAmp; var oldHat = ~hatAmp; var oldClap = ~clapAmp;
    ~kickAmp = 0; ~hatAmp = 0; ~clapAmp = 0; ~reload.value;
    Synth(\sweep, [\dur, 2, \startCutoff, 8000, \endCutoff, 200, \amp, 0.4]);
    2.wait;
    Synth(\impact, [\freq, 35, \decay, 2, \amp, 0.7]);
    ~kickAmp = oldKick; ~hatAmp = oldHat; ~clapAmp = oldClap; ~reload.value;
}).play;
"=== DROP CUT ===".postln;
)

// === BREAK (mute tout sauf melody, 8 secondes, puis riser + retour) ==
(
Routine({
    var oldKick = ~kickAmp; var oldHat = ~hatAmp; var oldClap = ~clapAmp;
    var oldSnare = ~snareAmp;
    ~kickAmp = 0; ~hatAmp = 0; ~clapAmp = 0; ~snareAmp = 0; ~reload.value;
    8.wait;
    Synth(\riser, [\dur, 4, \startCutoff, 400, \endCutoff, 11000, \amp, 0.35]);
    4.wait;
    Synth(\impact, [\freq, 38, \decay, 2, \amp, 0.6]);
    ~kickAmp = oldKick; ~hatAmp = oldHat; ~clapAmp = oldClap; ~snareAmp = oldSnare;
    ~reload.value;
}).play;
"=== BREAK 12s ===".postln;
)
