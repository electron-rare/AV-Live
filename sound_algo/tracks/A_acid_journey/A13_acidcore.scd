// =====================================================================
//  A13_acidcore.scd  --  Album A "Acid Journey", track 13/15
//  Track autonome -- Cmd+Entree sur le bloc (...) pour la lancer.
// =====================================================================

// --- TRACK A13 : "ACIDCORE" 4 minutes -------------------------------
//   0:00 gabber kick -> 0:45 303 distort -> 2:00 hard lead -> 3:00 peak -> 3:30 outro
(
~track !? { ~track.stop };
~track = Routine({
    ~trackBegin !? { ~trackBegin.value };
    "[A13 0:00] gabber kick -- distorted four-on-floor...".postln;
    ~bpm = 145;
    ~kickFreq = 70; ~kickPitchAmt = 6.0; ~kickDecay = 0.22;
    ~kickDrive = 4.5; ~kickClick = 0.40; ~kickAmp = 0.68;
    ~kickSteps = [1,0,1,0, 1,0,1,0, 1,0,1,0, 1,0,1,0];
    ~hatSteps = [0,0,1,1, 0,0,1,1, 0,0,1,1, 0,0,1,1]; ~hatAmp = 0.18;
    ~acidAmp = 0; ~melodyAmp = 0;
    TempoClock.default.tempo = ~bpm/60;
    ~fxPreset !? { ~fxPreset.(\industrial) };
    ~reload.value;
    ~playActive !? { ~playActive.value } ?? { ~allSeqs.do { |k| Pdef(k).play } };
    ~enableHarmony.(\off);
    45.wait;

    "[A13 0:45] 303 distort -- phrygian acid...".postln;
    ~acidAmp = 0.36; ~acidCutoff = 1200; ~acidRq = 0.10; ~acidDrive = 4.0;
    ~acidNotes = [36,49,36,37, 41,36,48,36, 37,49,36,41, 36,43,36,37];
    ~acidSlides = [0,0,1,0, 0,1,0,0, 0,0,0,1, 0,0,0,1];
    ~reload.value;
    Pdef(\acidSeq).play;
    // 75s 303 evolve
    15.do { |k|
        if (0.35.coin) { ~acidCutoff = rrand(800, 1700); ~reload.value };
        if (0.25.coin) {
            ~acidNotes = ~genMelody.(0.85, ~scalePhrygian);
            ~acidSlides = ~genAcidSlides.(0.45);
            ~reload.value;
        };
        5.wait;
    };

    "[A13 2:00] hard lead -- screaming...".postln;
    ~melodyInst = \hard_lead;
    ~melodyAttack = 0.001; ~melodyRelease = 0.10; ~melodyCutoff = 2800;
    ~melodyAmp = 0.20; ~melodyDrive = 4.0;
    ~melodyNotes = [60,0,61,0, 63,0,68,0, 65,67,68,0, 70,0,68,67,
                    63,0,61,0, 67,0,68,0, 0,68,67,63, 61,0,0,0];
    ~reload.value;
    Pdef(\melodySeq).play;
    ~vcfOn !? { ~vcfOn.(\ms20, 2200, 0.60) };
    // 60s lead phrygian
    12.do { |k|
        if (0.30.coin) {
            ~melodyNotes = ~genMelody.(0.70, ~scalePhrygian);
            ~reload.value;
        };
        if (0.20.coin) {
            ~melodyNotes = ~transpose.(~melodyNotes, [-5, 5].choose);
            ~reload.value;
        };
        5.wait;
    };

    "[A13 3:00] peak -- BPM up + everything maxed...".postln;
    ~bpm = 150;
    ~kickDrive = 5.0; ~acidCutoff = 1900; ~acidDrive = 4.5;
    ~melodyAmp = 0.24; ~melodyDrive = 4.5;
    ~hatSteps = [1,1,1,1, 1,1,1,1, 1,1,1,1, 1,1,1,1]; ~hatAmp = 0.20;
    TempoClock.default.tempo = ~bpm/60;
    ~reload.value;
    30.wait;

    "[A13 3:30] outro -- hard fade...".postln;
    ~vcfOff !? { ~vcfOff.() };
    30.do { |k|
        var x = 1 - ((k + 1) / 30);
        ~kickAmp = x * 0.68; ~hatAmp = x * 0.20;
        ~melodyAmp = x * 0.24; ~acidAmp = x * 0.36;
        ~reload.value;
        1.wait;
    };
    [\kickSeq, \hatSeq, \acidSeq, \melodySeq].do { |k| Pdef(k).stop };
    ~fxPreset !? { ~fxPreset.(\dry) };
    "[A13 4:00] === fin ACIDCORE ===".postln;
}).play;
"=== TRACK A13 : ACIDCORE 4 min lancee ===".postln;
)
