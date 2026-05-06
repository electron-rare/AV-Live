// =====================================================================
//  E03_guzheng_dance.scd  --  Album E "Vietnam Hard", track 3/15
//  Track autonome -- Cmd+Entree sur le bloc (...) pour la lancer.
// =====================================================================

// --- TRACK E03 : "GUZHENG DANCE" 6 min ---------------------
//   0:00 intro -> 1:22 build -> 2:44 climax -> 4:06 outro
(
~track !? { ~track.stop };
~track = Routine({
    ~trackBegin !? { ~trackBegin.value };
    "[E03 0:00] intro guzheng...".postln;
    ~bpm = 118;
    ~kickFreq = 55; ~kickPitchAmt = 3.0; ~kickDecay = 0.35;
    ~kickDrive = 1.5; ~kickClick = 0.2; ~kickAmp = 0.52;
    ~kickSteps = [1,0,0,0,1,0,0,0,1,0,0,0,1,0,0,0];
    ~hatSteps = [1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1]; ~hatAmp = 0.10;
    ~melodyInst = \guzheng; ~melodyAttack = 0.4; ~melodyRelease = 1.5;
    ~melodyCutoff = 1800; ~melodyAmp = 0.16;
    ~melodyNotes = [60,0,63,0,65,67,70,0,72,0,70,67,65,0,63,60,63,0,65,0,67,70,72,75,70,67,0,65,67,0,63,60];
    ~acidNotes = [36,36,48,36,39,36,43,39,36,41,36,39,43,36,36,41];
    ~acidCutoff = 700; ~acidRq = 0.2; ~acidDrive = 2.0; ~acidAmp = 0.22;
    TempoClock.default.tempo = ~bpm/60;
    ~fxPreset !? { ~fxPreset.(\space) };
    ~reload.value;
    ~playActive !? { ~playActive.value } ?? { ~allSeqs.do { |k| Pdef(k).play } };
    ~enableHarmony.(\arp);
    82.wait;

    "[E03 1:22] build...".postln;
    ~bpm = 118; ~melodyCutoff = 2400; ~acidCutoff = 1000; ~acidDrive = 2.5;
    ~melodyAttack = 0.01; ~melodyRelease = 0.4;
    TempoClock.default.tempo = ~bpm/60;
    ~reload.value;
    16.do { |k|
        if (0.20.coin) { ~melodyNotes = ~mutate.(~melodyNotes, 0.2, ~scaleVietnam); ~reload.value };
        if (0.15.coin) { ~acidCutoff = rrand(700, 1500); ~reload.value };
        if (0.10.coin) { ~melodyCutoff = rrand(1800, 3500); ~reload.value };
        5.wait;
    };

    "[E03 2:44] climax...".postln;
    ~bpm = 120; ~acidCutoff = 1400; ~acidDrive = 3.2; ~melodyAmp = 0.18;
    ~hatAmp = 0.14;
    TempoClock.default.tempo = ~bpm/60;
    ~reload.value;
    16.do { |k|
        if (0.25.coin) { ~melodyNotes = ~genMelody.(0.5, ~scaleVietnam); ~reload.value };
        if (0.20.coin) { ~acidCutoff = rrand(900, 1800); ~reload.value };
        if (0.10.coin) { ~acidSlides = ~genAcidSlides.(0.3); ~reload.value };
        if (0.07.coin) { ~melodyNotes = ~transpose.(~melodyNotes, [-5,-3,3,5,7].choose); ~reload.value };
        5.wait;
    };

    "[E03 4:06] outro section...".postln;
    ~bpm = 118; ~acidCutoff = 800; ~melodyAmp = 0.14;
    TempoClock.default.tempo = ~bpm/60;
    ~reload.value;
    10.do { |k|
        if (0.15.coin) { ~melodyNotes = ~mutate.(~melodyNotes, 0.15, ~scaleVietnam); ~reload.value };
        5.wait;
    };

    "[E03 5:00] outro -- fade...".postln;
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
    "[E03 5:30] === fin Guzheng Dance ===".postln;
}).play;
"=== TRACK E03 : GUZHENG DANCE 6 min lancee ===".postln;
)
