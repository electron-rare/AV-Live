// =====================================================================
//  C03_minimal_pulse.scd  --  Album C "Hypnotic Loop", track 3/15
//  Track autonome -- Cmd+Entree sur le bloc (...) pour la lancer.
// =====================================================================

// --- TRACK C03 : "MINIMAL PULSE" 6 min ---------------------
//   0:00 intro -> 1:22 build -> 2:44 climax -> 4:06 outro
(
~track !? { ~track.stop };
~track = Routine({
    ~trackBegin !? { ~trackBegin.value };
    "[C03 0:00] intro stab...".postln;
    ~bpm = 125;
    ~kickFreq = 55; ~kickPitchAmt = 3.0; ~kickDecay = 0.3;
    ~kickDrive = 1.5; ~kickClick = 0.2; ~kickAmp = 0.52;
    ~kickSteps = [1,0,0,0,1,0,0,0,1,0,0,0,1,0,0,0];
    ~hatSteps = [1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1]; ~hatAmp = 0.10;
    ~melodyInst = \stab; ~melodyAttack = 0.4; ~melodyRelease = 1.5;
    ~melodyCutoff = 1800; ~melodyAmp = 0.16;
    ~melodyNotes = [60,0,0,63,0,67,0,70,67,0,63,0,60,0,0,0,60,0,63,0,67,0,70,0,72,0,70,67,63,0,60,0];
    ~acidNotes = [36,36,48,36,39,36,43,39,36,41,36,39,43,36,36,41];
    ~acidCutoff = 700; ~acidRq = 0.2; ~acidDrive = 2.0; ~acidAmp = 0.22;
    TempoClock.default.tempo = ~bpm/60;
    ~fxPreset !? { ~fxPreset.(\dry) };
    ~reload.value;
    ~playActive !? { ~playActive.value } ?? { ~allSeqs.do { |k| Pdef(k).play } };
    ~enableHarmony.(\third);
    82.wait;

    "[C03 1:22] build...".postln;
    ~bpm = 125; ~melodyCutoff = 2400; ~acidCutoff = 1000; ~acidDrive = 2.5;
    ~melodyAttack = 0.01; ~melodyRelease = 0.4;
    TempoClock.default.tempo = ~bpm/60;
    ~reload.value;
    16.do { |k|
        if (0.20.coin) { ~melodyNotes = ~mutate.(~melodyNotes, 0.2, ~scaleMinor); ~reload.value };
        if (0.15.coin) { ~acidCutoff = rrand(700, 1500); ~reload.value };
        if (0.10.coin) { ~melodyCutoff = rrand(1800, 3500); ~reload.value };
        5.wait;
    };

    "[C03 2:44] climax...".postln;
    ~bpm = 127; ~acidCutoff = 1400; ~acidDrive = 3.2; ~melodyAmp = 0.18;
    ~hatAmp = 0.14;
    TempoClock.default.tempo = ~bpm/60;
    ~reload.value;
    16.do { |k|
        if (0.25.coin) { ~melodyNotes = ~genMelody.(0.5, ~scaleMinor); ~reload.value };
        if (0.20.coin) { ~acidCutoff = rrand(900, 1800); ~reload.value };
        if (0.10.coin) { ~acidSlides = ~genAcidSlides.(0.3); ~reload.value };
        if (0.07.coin) { ~melodyNotes = ~transpose.(~melodyNotes, [-5,-3,3,5,7].choose); ~reload.value };
        5.wait;
    };

    "[C03 4:06] outro section...".postln;
    ~bpm = 125; ~acidCutoff = 800; ~melodyAmp = 0.14;
    TempoClock.default.tempo = ~bpm/60;
    ~reload.value;
    10.do { |k|
        if (0.15.coin) { ~melodyNotes = ~mutate.(~melodyNotes, 0.15, ~scaleMinor); ~reload.value };
        5.wait;
    };

    "[C03 5:00] outro -- fade...".postln;
    30.do { |k|
        var x = 1 - ((k + 1) / 30);
        ~melodyAmp = x * 0.18;
        ~acidAmp = x * 0.22;
        ~kickAmp = x * 0.52;
        ~hatAmp = x * 0.14;
        ~reload.value;
        1.wait;
    };
    [\kickSeq, \hatSeq, \snareSeq, \clapSeq, \percSeq, \acidSeq, \melodySeq, \harmonySeq].do { |k| Pdef(k).stop };
    ~fxPreset !? { ~fxPreset.(\dry) };
    "[C03 5:30] === fin Minimal Pulse ===".postln;
}).play;
"=== TRACK C03 : MINIMAL PULSE 6 min lancee ===".postln;
)
