// =====================================================================
//  A07_acid_techno.scd  --  Album A "Acid Journey", track 7/15
//  Track autonome -- Cmd+Entree sur le bloc (...) pour la lancer.
// =====================================================================

// --- TRACK A07 : "ACID TECHNO (Berlin)" 6 minutes -------------------
//   0:00 hard kick -> 1:00 303 line -> 2:30 lead enter -> 4:00 peak -> 5:00 outro
(
~track !? { ~track.stop };
~track = Routine({
    ~trackBegin !? { ~trackBegin.value };
    "[A07 0:00] hard kick -- techno punisher...".postln;
    ~bpm = 135;
    ~kickFreq = 55; ~kickPitchAmt = 4.0; ~kickDecay = 0.30;
    ~kickDrive = 2.5; ~kickClick = 0.40; ~kickAmp = 0.62;
    ~kickSteps = [1,0,0,0, 1,0,0,0, 1,0,0,0, 1,0,0,0];
    ~hatSteps = [0,0,1,0, 0,0,1,0, 0,0,1,0, 0,0,1,1]; ~hatAmp = 0.18;
    ~clapSteps = [0,0,0,0, 1,0,0,0, 0,0,0,0, 1,0,0,0]; ~clapAmp = 0.55;
    ~acidAmp = 0; ~melodyAmp = 0;
    TempoClock.default.tempo = ~bpm/60;
    ~reload.value;
    ~playActive !? { ~playActive.value } ?? { ~allSeqs.do { |k| Pdef(k).play } };
    ~enableHarmony.(\off);
    60.wait;

    "[A07 1:00] 303 line -- berlin acid Phrygian...".postln;
    ~acidAmp = 0.34; ~acidCutoff = 900; ~acidRq = 0.13; ~acidDrive = 3.0;
    ~acidNotes = [36,36,49,36, 41,36,48,36, 37,36,43,36, 49,36,41,36];
    ~acidSlides = [0,1,0,0, 0,1,0,0, 0,0,1,0, 0,0,0,1];
    ~reload.value;
    Pdef(\acidSeq).play;
    // 90s 303 sweep
    18.do { |k|
        ~acidCutoff = 700 + (k * 30);
        if (0.30.coin) { ~acidRq = rrand(0.10, 0.18); ~reload.value };
        if (0.25.coin) {
            ~acidNotes = ~genMelody.(0.7, ~scaleAcidWide);
            ~acidSlides = ~genAcidSlides.(0.35);
            ~reload.value;
        };
        ~reload.value;
        5.wait;
    };

    "[A07 2:30] lead enter -- square stab phrygian...".postln;
    ~melodyInst = \square_lead;
    ~melodyAttack = 0.005; ~melodyRelease = 0.18; ~melodyCutoff = 2400;
    ~melodyAmp = 0.16; ~melodyDrive = 2.0;
    ~melodyNotes = [60,0,61,0, 0,67,0,63, 0,68,0,0, 65,0,67,0,
                    63,0,0,61, 67,0,0,68, 0,63,0,67, 0,65,0,0];
    ~reload.value;
    Pdef(\melodySeq).play;
    // 90s lead phrygian variations
    18.do { |k|
        if (0.30.coin) {
            ~melodyNotes = ~genMelody.(0.55, ~scalePhrygian);
            ~reload.value;
        };
        if (0.20.coin) {
            ~melodyNotes = ~transpose.(~melodyNotes, [-7, -5, 5, 7].choose);
            ~reload.value;
        };
        if (0.15.coin) { ~melodyCutoff = rrand(1800, 3200); ~reload.value };
        5.wait;
    };

    "[A07 4:00] peak -- everything drives...".postln;
    ~bpm = 138;
    ~kickDrive = 3.2; ~acidCutoff = 1500; ~acidDrive = 3.5;
    ~melodyAmp = 0.20; ~melodyDrive = 2.8;
    ~hatSteps = [1,1,1,1, 1,1,1,1, 1,1,1,1, 1,1,1,1]; ~hatAmp = 0.16;
    ~vcfOn !? { ~vcfOn.(\moog, 1500, 0.5) };
    TempoClock.default.tempo = ~bpm/60;
    ~reload.value;
    60.wait;

    "[A07 5:00] outro -- filter close...".postln;
    ~vcfOff !? { ~vcfOff.() };
    60.do { |k|
        var x = 1 - ((k + 1) / 60);
        ~kickAmp = x * 0.62; ~hatAmp = x * 0.16; ~clapAmp = x * 0.55;
        ~melodyAmp = x * 0.20; ~acidAmp = x * 0.34;
        ~acidCutoff = 200 + (x * 1300);
        ~reload.value;
        1.wait;
    };
    [\kickSeq, \hatSeq, \clapSeq, \acidSeq, \melodySeq].do { |k| Pdef(k).stop };
    "[A07 6:00] === fin ACID TECHNO ===".postln;
}).play;
"=== TRACK A07 : ACID TECHNO 6 min lancee ===".postln;
)
