// =====================================================================
//  F14_drop_anthem.scd  --  Album F "Trance Uplifter", track 14/15
//  Track autonome -- Cmd+Entree sur le bloc (...) pour la lancer.
// =====================================================================

// --- TRACK F14 : "DROP ANTHEM" 5 min ---------------------
//   0:00 intro -> 1:07 build -> 2:14 climax -> 3:21 outro
(
~track !? { ~track.stop };
~track = Routine({
    ~trackBegin !? { ~trackBegin.value };
    "[F14 0:00] intro supersaw...".postln;
    ~bpm = 140;
    ~kickFreq = 55; ~kickPitchAmt = 3.2; ~kickDecay = 0.28;
    ~kickDrive = 1.5; ~kickClick = 0.2; ~kickAmp = 0.55;
    ~kickSteps = [1,0,0,0,1,0,0,0,1,0,0,0,1,0,0,0];
    ~hatSteps = [1,0,1,0,1,0,1,0,1,0,1,0,1,0,1,0]; ~hatAmp = 0.10;
    ~melodyInst = \supersaw; ~melodyAttack = 0.4; ~melodyRelease = 1.5;
    ~melodyCutoff = 1800; ~melodyAmp = 0.16;
    ~melodyNotes = [60,67,72,75,70,67,63,60,65,72,77,79,75,72,70,67,67,72,75,79,75,72,67,65,63,67,72,75,70,67,63,60];
    ~acidNotes = [36,36,48,36,39,36,43,39,36,41,36,39,43,36,36,41];
    ~acidCutoff = 700; ~acidRq = 0.2; ~acidDrive = 2.0; ~acidAmp = 0.22;
    TempoClock.default.tempo = ~bpm/60;
    ~fxPreset !? { ~fxPreset.(\trance) };
    ~reload.value;
    ~playActive !? { ~playActive.value } ?? { ~allSeqs.do { |k| Pdef(k).play } };
    ~enableHarmony.(\tranceLayer);
    67.wait;

    "[F14 1:07] build...".postln;
    ~bpm = 140; ~melodyCutoff = 2400; ~acidCutoff = 1000; ~acidDrive = 2.5;
    ~melodyAttack = 0.01; ~melodyRelease = 0.4;
    TempoClock.default.tempo = ~bpm/60;
    ~reload.value;
    13.do { |k|
        if (0.20.coin) { ~melodyNotes = ~mutate.(~melodyNotes, 0.2, ~scaleHarmonicMin); ~reload.value };
        if (0.15.coin) { ~acidCutoff = rrand(700, 1500); ~reload.value };
        if (0.10.coin) { ~melodyCutoff = rrand(1800, 3500); ~reload.value };
        5.wait;
    };

    "[F14 2:14] climax...".postln;
    ~bpm = 142; ~acidCutoff = 1400; ~acidDrive = 3.2; ~melodyAmp = 0.18;
    ~hatAmp = 0.14;
    TempoClock.default.tempo = ~bpm/60;
    ~reload.value;
    13.do { |k|
        if (0.25.coin) { ~melodyNotes = ~genMelody.(0.5, ~scaleHarmonicMin); ~reload.value };
        if (0.20.coin) { ~acidCutoff = rrand(900, 1800); ~reload.value };
        if (0.10.coin) { ~acidSlides = ~genAcidSlides.(0.3); ~reload.value };
        if (0.07.coin) { ~melodyNotes = ~transpose.(~melodyNotes, [-5,-3,3,5,7].choose); ~reload.value };
        5.wait;
    };

    "[F14 3:21] outro section...".postln;
    ~bpm = 140; ~acidCutoff = 800; ~melodyAmp = 0.14;
    TempoClock.default.tempo = ~bpm/60;
    ~reload.value;
    7.do { |k|
        if (0.15.coin) { ~melodyNotes = ~mutate.(~melodyNotes, 0.15, ~scaleHarmonicMin); ~reload.value };
        5.wait;
    };

    "[F14 4:00] outro -- fade...".postln;
    30.do { |k|
        var x = 1 - ((k + 1) / 30);
        ~melodyAmp = x * 0.18;
        ~acidAmp = x * 0.22;
        ~kickAmp = x * 0.55;
        ~hatAmp = x * 0.14;
        ~reload.value;
        1.wait;
    };
    [\kickSeq, \hatSeq, \snareSeq, \clapSeq, \percSeq, \acidSeq, \melodySeq, \harmonySeq].do { |k| Pdef(k).stop };
    ~fxPreset !? { ~fxPreset.(\dry) };
    "[F14 4:30] === fin Drop Anthem ===".postln;
}).play;
"=== TRACK F14 : DROP ANTHEM 5 min lancee ===".postln;
)
