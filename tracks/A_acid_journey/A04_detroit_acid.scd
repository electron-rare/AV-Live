// =====================================================================
//  A04_detroit_acid.scd  --  Album A "Acid Journey", track 4/15
//  Track autonome -- Cmd+Entree sur le bloc (...) pour la lancer.
// =====================================================================

// --- TRACK A04 : "DETROIT ACID" 5 minutes ---------------------------
//   0:00 cold pads -> 1:00 stab enter -> 2:30 acid line -> 4:00 climax -> 4:30 outro
(
~track !? { ~track.stop };
~track = Routine({
    ~trackBegin !? { ~trackBegin.value };
    "[A04 0:00] cold pads -- intro Detroit machine soul...".postln;
    ~bpm = 128;
    ~kickFreq = 60; ~kickPitchAmt = 3.5; ~kickDecay = 0.22;
    ~kickDrive = 1.5; ~kickClick = 0.35; ~kickAmp = 0.55;
    ~kickSteps = [1,0,0,0, 1,0,0,0, 1,0,0,0, 1,0,0,0];
    ~hatAmp = 0; ~clapAmp = 0;
    ~acidAmp = 0;
    ~melodyInst = \warm_pad;
    ~melodyAttack = 0.8; ~melodyRelease = 2.5; ~melodyCutoff = 1200;
    ~melodyAmp = 0.13;
    ~melodyNotes = [60,0,0,0,0,0,0,0, 63,0,0,0,0,0,0,0,
                    67,0,0,0,0,0,0,0, 65,0,0,0,0,0,0,0];
    TempoClock.default.tempo = ~bpm/60;
    ~reload.value;
    ~playActive !? { ~playActive.value } ?? { ~allSeqs.do { |k| Pdef(k).play } };
    ~enableHarmony.(\fifth);
    Pdef(\harmonySeq).play;
    60.wait;

    "[A04 1:00] stab enter -- detroit chord stabs...".postln;
    ~melodyInst = \stab;
    ~melodyAttack = 0.001; ~melodyRelease = 0.08;
    ~melodyDrive = 2.5; ~melodyCutoff = 1600; ~melodyAmp = 0.15;
    ~melodyNotes = [63,0,0,0, 70,0,67,0, 65,0,0,0, 70,0,72,0,
                    63,0,0,0, 67,0,70,0, 65,0,60,0, 67,0,0,0];
    ~hatSteps = [0,0,1,0, 0,0,1,0, 0,0,1,0, 0,0,1,0]; ~hatAmp = 0.12;
    ~clapSteps = [0,0,0,0, 1,0,0,0, 0,0,0,0, 1,0,0,0]; ~clapAmp = 0.5;
    ~enableHarmony.(\off);
    ~reload.value;
    ~playActive !? { ~playActive.value } ?? { ~allSeqs.do { |k| Pdef(k).play } };
    // 90s stabs evoluant
    18.do { |k|
        if (0.30.coin) {
            ~melodyNotes = ~genMelody.(0.4, [~scaleMinor, ~scaleDorian].choose);
            ~reload.value;
        };
        if (0.18.coin) { ~melodyCutoff = rrand(1100, 2200); ~reload.value };
        if (0.12.coin) {
            ~melodyNotes = ~transpose.(~melodyNotes, [-5, -3, 3, 5, 7].choose);
            ~reload.value;
        };
        5.wait;
    };

    "[A04 2:30] acid line -- 303 + stabs ride together...".postln;
    ~acidAmp = 0.26; ~acidCutoff = 750; ~acidRq = 0.16; ~acidDrive = 2.4;
    ~acidNotes = [36,36,48,36, 39,36,43,39, 36,41,36,39, 43,36,36,41];
    ~acidSlides = [0,0,1,0, 0,0,0,1, 0,0,0,1, 0,0,0,0];
    ~reload.value;
    Pdef(\acidSeq).play;
    // 90s acid + stabs
    18.do { |k|
        if (0.25.coin) { ~acidCutoff = rrand(550, 1200); ~reload.value };
        if (0.20.coin) {
            ~melodyNotes = ~mutate.(~melodyNotes, 0.25, ~scaleHarmonicMin);
            ~reload.value;
        };
        if (0.15.coin) { ~kickClick = rrand(0.25, 0.5); ~reload.value };
        5.wait;
    };

    "[A04 4:00] climax -- everything raised...".postln;
    ~acidCutoff = 1400; ~melodyAmp = 0.18; ~kickDrive = 2.0;
    ~hatSteps = [1,0,1,1, 1,0,1,1, 1,0,1,1, 1,0,1,1]; ~hatAmp = 0.16;
    ~reload.value;
    30.wait;

    "[A04 4:30] outro -- short fade...".postln;
    30.do { |k|
        var x = 1 - ((k + 1) / 30);
        ~kickAmp = x * 0.55; ~hatAmp = x * 0.16; ~clapAmp = x * 0.5;
        ~melodyAmp = x * 0.18; ~acidAmp = x * 0.26;
        ~reload.value;
        1.wait;
    };
    [\kickSeq, \hatSeq, \clapSeq, \acidSeq, \melodySeq, \harmonySeq].do { |k| Pdef(k).stop };
    "[A04 5:00] === fin DETROIT ACID ===".postln;
}).play;
"=== TRACK A04 : DETROIT ACID 5 min lancee ===".postln;
)
