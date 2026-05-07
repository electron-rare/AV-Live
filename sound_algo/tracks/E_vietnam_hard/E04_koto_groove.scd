// =====================================================================
//  E04_koto_groove.scd  --  Album E "Vietnam Hard", track 4/15
//  Track autonome -- Cmd+Entree sur le bloc (...) pour la lancer.
// =====================================================================

// --- TRACK E04 : "KOTO GROOVE" 7 min ---------------------
//   0:00 intro -> 1:37 build -> 3:14 climax -> 4:51 outro
(
~track !? { ~track.stop };
~track = Routine({
    ~trackBegin !? { ~trackBegin.value };
    "[E04 0:00] intro koto...".postln;
    ~bpm = 120;
    ~kickFreq = 55; ~kickPitchAmt = 3.0; ~kickDecay = 0.32;
    ~kickDrive = 1.5; ~kickClick = 0.2; ~kickAmp = 0.55;
    ~kickSteps = [1,0,0,0,1,0,0,0,1,0,0,0,1,0,0,0];
    ~hatSteps = [0,1,0,1,0,1,0,1,0,1,0,1,0,1,0,1]; ~hatAmp = 0.10;
    ~melodyInst = \koto; ~melodyAttack = 0.4; ~melodyRelease = 1.5;
    ~melodyCutoff = 1800; ~melodyAmp = 0.16;
    ~melodyNotes = [60,0,63,0,65,67,70,0,72,0,70,67,65,0,63,60,63,0,65,0,67,70,72,75,70,67,0,65,67,0,63,60];
    ~acidNotes = [36,36,48,36,39,36,43,39,36,41,36,39,43,36,36,41];
    ~acidCutoff = 700; ~acidRq = 0.2; ~acidDrive = 2.0; ~acidAmp = 0.22;
    TempoClock.default.tempo = ~bpm/60;
    ~fxPreset !? { ~fxPreset.(\dry) };
    ~reload.value;
    ~playActive !? { ~playActive.value } ?? { ~allSeqs.do { |k| Pdef(k).play } };
    ~enableHarmony.(\fifth);
    97.wait;

    "[E04 1:37] build...".postln;
    ~bpm = 120; ~melodyCutoff = 2400; ~acidCutoff = 1000; ~acidDrive = 2.5;
    ~melodyAttack = 0.01; ~melodyRelease = 0.4;
    TempoClock.default.tempo = ~bpm/60;
    ~reload.value;
    19.do { |k|
        if (0.20.coin) { ~melodyNotes = ~mutate.(~melodyNotes, 0.2, ~scaleHirajoshi); ~reload.value };
        if (0.15.coin) { ~acidCutoff = rrand(700, 1500); ~reload.value };
        if (0.10.coin) { ~melodyCutoff = rrand(1800, 3500); ~reload.value };
        5.wait;
    };

    "[E04 3:14] climax...".postln;
    ~bpm = 122; ~acidCutoff = 1400; ~acidDrive = 3.2; ~melodyAmp = 0.18;
    ~hatAmp = 0.14;
    TempoClock.default.tempo = ~bpm/60;
    ~reload.value;
    19.do { |k|
        if (0.25.coin) { ~melodyNotes = ~genMelody.(0.5, ~scaleHirajoshi); ~reload.value };
        if (0.20.coin) { ~acidCutoff = rrand(900, 1800); ~reload.value };
        if (0.10.coin) { ~acidSlides = ~genAcidSlides.(0.3); ~reload.value };
        if (0.07.coin) { ~melodyNotes = ~transpose.(~melodyNotes, [-5,-3,3,5,7].choose); ~reload.value };
        5.wait;
    };

    "[E04 4:51] outro section...".postln;
    ~bpm = 120; ~acidCutoff = 800; ~melodyAmp = 0.14;
    TempoClock.default.tempo = ~bpm/60;
    ~reload.value;
    13.do { |k|
        if (0.15.coin) { ~melodyNotes = ~mutate.(~melodyNotes, 0.15, ~scaleHirajoshi); ~reload.value };
        5.wait;
    };

    "[E04 6:00] outro -- fade...".postln;
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
    "[E04 6:30] === fin Koto Groove ===".postln;
}).play;
"=== TRACK E04 : KOTO GROOVE 7 min lancee ===".postln;
)
