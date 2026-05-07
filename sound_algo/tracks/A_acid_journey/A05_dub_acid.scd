// =====================================================================
//  A05_dub_acid.scd  --  Album A "Acid Journey", track 5/15
//  Track autonome -- Cmd+Entree sur le bloc (...) pour la lancer.
// =====================================================================

// --- TRACK A05 : "DUB ACID" 7 minutes -------------------------------
//   0:00 dub chord -> 1:30 acid sub -> 3:30 echo break -> 5:00 climax -> 6:30 outro
(
~track !? { ~track.stop };
~track = Routine({
    ~trackBegin !? { ~trackBegin.value };
    "[A05 0:00] dub chord -- chorus + delay long...".postln;
    ~bpm = 118;
    ~kickFreq = 45; ~kickPitchAmt = 1.8; ~kickDecay = 0.55;
    ~kickDrive = 1.0; ~kickClick = 0.06; ~kickAmp = 0.50;
    ~kickSteps = [1,0,0,0, 0,0,0,0, 1,0,0,0, 0,0,0,0];
    ~hatAmp = 0;
    ~acidAmp = 0;
    ~melodyInst = \rhodes;
    ~melodyAttack = 0.05; ~melodyRelease = 1.8; ~melodyCutoff = 1400;
    ~melodyAmp = 0.13;
    ~melodyNotes = [60,0,0,0,0,0,0,0, 0,0,0,0, 65,0,0,0,
                    0,0,0,0, 67,0,0,0, 0,0,0,0, 70,0,0,0];
    TempoClock.default.tempo = ~bpm/60;
    ~fxPreset !? { ~fxPreset.(\dub) };
    ~reload.value;
    ~playActive !? { ~playActive.value } ?? { ~allSeqs.do { |k| Pdef(k).play } };
    ~enableHarmony.(\dubBass);
    Pdef(\harmonySeq).play;
    90.wait;

    "[A05 1:30] acid sub -- 303 deep + hat 16th low...".postln;
    ~hatSteps = [0,1,0,1, 0,1,0,1, 0,1,0,1, 0,1,0,1]; ~hatAmp = 0.07;
    ~acidAmp = 0.24; ~acidCutoff = 500; ~acidRq = 0.20; ~acidDrive = 1.6;
    ~acidNotes = [36,36,36,36, 36,39,36,36, 36,36,41,36, 36,36,36,43];
    ~acidSlides = [0,0,0,0, 0,0,0,0, 0,0,1,0, 0,0,0,1];
    ~reload.value;
    ~playActive !? { ~playActive.value } ?? { ~allSeqs.do { |k| Pdef(k).play } };
    // 120s 303 + dub progress
    24.do { |k|
        if (0.18.coin) { ~acidCutoff = rrand(400, 850); ~reload.value };
        if (0.20.coin) {
            ~melodyNotes = ~genMelody.(0.35, ~scaleDorian);
            ~reload.value;
        };
        if (0.10.coin) {
            ~melodyNotes = ~octavate.(~melodyNotes, 0.2);
            ~reload.value;
        };
        5.wait;
    };

    "[A05 3:30] echo break -- kick out, echo space...".postln;
    ~kickAmp = 0; ~hatAmp = 0;
    ~acidCutoff = 900; ~melodyAmp = 0.15;
    ~stutter !? { ~stutter.(6, 1.2) };
    ~reload.value;
    // 90s rhodes seul + 303 dans le brouillard
    18.do { |k|
        if (0.30.coin) {
            ~melodyNotes = ~mutate.(~melodyNotes, 0.3, ~scaleDorian);
            ~reload.value;
        };
        if (0.20.coin) { ~acidCutoff = rrand(700, 1300); ~reload.value };
        5.wait;
    };

    "[A05 5:00] climax -- kick revient + everything wide...".postln;
    ~kickAmp = 0.55; ~hatAmp = 0.12;
    ~hatSteps = [1,0,1,0, 1,0,1,0, 1,0,1,1, 1,0,1,0];
    ~acidCutoff = 1300; ~acidDrive = 2.3;
    ~melodyAmp = 0.18;
    ~reload.value;
    90.wait;

    "[A05 6:30] outro -- echo emporte tout...".postln;
    [\kickSeq, \hatSeq].do { |k| Pdef(k).stop };
    30.do { |k|
        var x = 1 - ((k + 1) / 30);
        ~melodyAmp = x * 0.18; ~acidAmp = x * 0.24;
        ~acidCutoff = 200 + (x * 1100);
        ~reload.value;
        1.wait;
    };
    [\acidSeq, \melodySeq, \harmonySeq].do { |k| Pdef(k).stop };
    ~fxPreset !? { ~fxPreset.(\dry) };
    "[A05 7:00] === fin DUB ACID ===".postln;
}).play;
"=== TRACK A05 : DUB ACID 7 min lancee ===".postln;
)
