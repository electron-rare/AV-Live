// =====================================================================
//  A09_tribal_acid.scd  --  Album A "Acid Journey", track 9/15
//  Track autonome -- Cmd+Entree sur le bloc (...) pour la lancer.
// =====================================================================

// --- TRACK A09 : "TRIBAL ACID (World)" 7 minutes --------------------
//   0:00 percussion build -> 1:30 handpan -> 3:00 acid sub -> 4:30 climax -> 6:00 outro
(
~track !? { ~track.stop };
~track = Routine({
    ~trackBegin !? { ~trackBegin.value };
    "[A09 0:00] percussion build -- tabla + taiko intro...".postln;
    ~bpm = 128;
    ~kickFreq = 50; ~kickPitchAmt = 2.0; ~kickDecay = 0.40;
    ~kickDrive = 1.4; ~kickClick = 0.15; ~kickAmp = 0.45;
    ~kickSteps = [1,0,0,0, 0,0,1,0, 1,0,0,0, 0,1,0,0];
    ~hatAmp = 0;
    ~percSteps = [0,1,0,1, 1,0,1,0, 0,1,1,0, 1,0,1,1]; ~percAmp = 0.30;
    ~acidAmp = 0; ~melodyAmp = 0;
    TempoClock.default.tempo = ~bpm/60;
    ~reload.value;
    ~playActive !? { ~playActive.value } ?? { ~allSeqs.do { |k| Pdef(k).play } };
    ~enableHarmony.(\off);
    90.wait;

    "[A09 1:30] handpan -- vietnam pent...".postln;
    ~melodyInst = \handpan;
    ~melodyAttack = 0.005; ~melodyRelease = 1.4; ~melodyCutoff = 2200;
    ~melodyAmp = 0.16;
    ~melodyNotes = [60,0,67,0, 65,0,70,63, 67,0,0,72, 70,0,75,0,
                    63,0,67,0, 70,0,65,72, 0,67,0,75, 70,0,0,0];
    ~reload.value;
    Pdef(\melodySeq).play;
    // 90s handpan vietnam
    18.do { |k|
        if (0.25.coin) {
            ~melodyNotes = ~genMelody.(0.50, [~scaleVietnam, ~scaleVietnamMaj].choose);
            ~reload.value;
        };
        if (0.15.coin) {
            ~melodyNotes = ~octavate.(~melodyNotes, 0.2);
            ~reload.value;
        };
        if (0.20.coin) { ~melodyCutoff = rrand(1700, 2700); ~reload.value };
        5.wait;
    };

    "[A09 3:00] acid sub -- 303 wide low + handpan flies...".postln;
    ~hatSteps = [0,1,0,1, 0,1,0,1, 0,1,0,1, 0,1,0,1]; ~hatAmp = 0.08;
    ~acidAmp = 0.22; ~acidCutoff = 700; ~acidRq = 0.18; ~acidDrive = 2.0;
    ~acidNotes = [36,36,48,36, 36,39,36,43, 36,48,36,41, 36,39,36,36];
    ~acidSlides = [0,0,1,0, 0,0,0,1, 0,1,0,0, 0,0,0,0];
    ~reload.value;
    ~playActive !? { ~playActive.value } ?? { ~allSeqs.do { |k| Pdef(k).play } };
    // 90s
    18.do { |k|
        if (0.20.coin) { ~acidCutoff = rrand(550, 1100); ~reload.value };
        if (0.20.coin) {
            ~melodyNotes = ~mutate.(~melodyNotes, 0.25, ~scaleVietnam);
            ~reload.value;
        };
        5.wait;
    };

    "[A09 4:30] climax -- gong + everything ride...".postln;
    ~melodyInst = \gong;
    ~melodyAttack = 0.005; ~melodyRelease = 3.0; ~melodyCutoff = 1800;
    ~melodyAmp = 0.18;
    ~percAmp = 0.40; ~kickAmp = 0.55;
    ~hatSteps = [1,0,1,1, 1,0,1,1, 1,0,1,1, 1,0,1,1]; ~hatAmp = 0.14;
    ~reload.value;
    90.wait;

    "[A09 6:00] outro -- percussion seules s'eteignent...".postln;
    [\hatSeq, \acidSeq, \melodySeq].do { |k| Pdef(k).stop };
    ~melodyAmp = 0; ~acidAmp = 0;
    ~reload.value;
    60.do { |k|
        var x = 1 - ((k + 1) / 60);
        ~kickAmp = x * 0.55; ~percAmp = x * 0.40;
        ~reload.value;
        1.wait;
    };
    [\kickSeq, \percSeq].do { |k| Pdef(k).stop };
    "[A09 7:00] === fin TRIBAL ACID ===".postln;
}).play;
"=== TRACK A09 : TRIBAL ACID 7 min lancee ===".postln;
)
