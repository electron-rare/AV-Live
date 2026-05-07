// =====================================================================
//  G03_strings_of_life.scd  --  Album G, track 3/15
// =====================================================================

// --- TRACK G03 : "STRINGS OF LIFE" 6 minutes -------------------------
//   0:00 strings -> 1:00 kick -> 2:30 piano stabs -> 4:30 climax -> 5:30 outro
(
~track !? { ~track.stop };
~track = Routine({
    ~trackBegin !? { ~trackBegin.value };
    "[G03 0:00] strings intro -- hommage Rhythim...".postln;
    ~bpm = 124;
    ~melodyInst = \strings; ~melodyAttack = 0.3; ~melodyRelease = 1.2;
    ~melodyCutoff = 3500; ~melodyAmp = 0.20;
    ~melodyNotes = [60,0,0,0, 65,0,0,0, 67,0,0,0, 72,0,0,0,
                    74,0,0,0, 72,0,0,0, 67,0,0,0, 65,0,0,0];
    ~kickSteps=(0!16); ~hatSteps=(0!16); ~clapSteps=(0!16); ~acidAmp=0;
    TempoClock.default.tempo = ~bpm/60;
    ~fxPreset !? { ~fxPreset.(\space) };
    ~reload.value;
    ~playActive !? { ~playActive.value } ?? { ~allSeqs.do { |k| Pdef(k).play } };
    ~enableHarmony.(\fifth);
    60.wait;

    "[G03 1:00] kick 4/4 + perc...".postln;
    ~kickSteps = [1,0,0,0, 1,0,0,0, 1,0,0,0, 1,0,0,0]; ~kickAmp = 0.50;
    ~kickFreq = 52; ~kickPitchAmt = 3.0; ~kickDecay = 0.32; ~kickClick = 0.15;
    ~hatSteps = [0,0,1,0, 0,0,1,0, 0,0,1,0, 0,0,1,0]; ~hatAmp = 0.14;
    ~clapSteps = [0,0,0,0, 1,0,0,0, 0,0,0,0, 1,0,0,0]; ~clapAmp = 0.32;
    ~reload.value;
    90.wait;

    "[G03 2:30] stab piano variations...".postln;
    ~melodyInst = \stab;
    ~melodyAttack = 0.001; ~melodyRelease = 0.08; ~melodyCutoff = 4000;
    ~melodyDrive = 2.5; ~melodyAmp = 0.18;
    ~melodyNotes = [60,0,67,0, 72,0,67,0, 65,0,72,0, 67,0,65,0,
                    63,0,67,0, 70,0,67,0, 60,0,65,0, 63,0,60,0];
    ~reload.value;
    24.do { |k|
        if (0.22.coin) {
            ~melodyNotes = ~genMelody.(0.5,
                [~scaleMinorPent, ~scaleMinor, ~scaleDorian].choose);
            ~reload.value;
        };
        if (0.12.coin) { ~melodyDrive = rrand(2.0, 3.5); ~reload.value };
        5.wait;
    };

    "[G03 4:30] climax -- supersaw + strings...".postln;
    ~melodyInst = \supersaw;
    ~melodyAttack = 0.01; ~melodyRelease = 0.4; ~melodyCutoff = 4500;
    ~melodyAmp = 0.20;
    ~vcfOn !? { ~vcfOn.(\moog, 2500, 0.4) };
    ~reload.value;
    60.wait;

    "[G03 5:30] outro -- strings fade...".postln;
    ~vcfOff !? { ~vcfOff.() };
    ~melodyInst = \strings;
    ~melodyAttack = 0.4; ~melodyRelease = 1.5;
    ~reload.value;
    30.do { |k|
        var x = 1 - ((k + 1) / 30);
        ~kickAmp = x * 0.50; ~hatAmp = x * 0.14; ~clapAmp = x * 0.32;
        ~melodyAmp = x * 0.20;
        ~reload.value; 1.wait;
    };
    [\kickSeq, \hatSeq, \snareSeq, \clapSeq, \percSeq, \acidSeq, \melodySeq, \harmonySeq].do { |k| Pdef(k).stop };
    ~fxPreset !? { ~fxPreset.(\dry) };
    "[G03 6:00] === fin STRINGS OF LIFE ===".postln;
}).play;
"=== TRACK G03 : STRINGS OF LIFE 6 min lancee ===".postln;
)
