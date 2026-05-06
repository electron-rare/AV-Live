// =====================================================================
//  I06_jazzy_breaks.scd  --  Album I, track 6/15
// =====================================================================

// --- TRACK I06 : "JAZZY BREAKS" 6 minutes ----------------------------
//   0:00 rhodes -> 1:00 amen jazzy -> 2:30 fmLead -> 4:30 outro
(
~track !? { ~track.stop };
~track = Routine({
    ~trackBegin !? { ~trackBegin.value };
    "[I06 0:00] rhodes jazzy intro...".postln;
    ~bpm = 174;
    ~melodyInst = \rhodes; ~melodyAttack = 0.01; ~melodyRelease = 0.7;
    ~melodyCutoff = 3500; ~melodyAmp = 0.20;
    ~melodyNotes = ~genMelody.(0.55, ~scaleDorian);
    ~kickSteps=(0!16); ~hatSteps=(0!16); ~snareSteps=(0!16); ~acidAmp=0;
    TempoClock.default.tempo = ~bpm/60;
    ~fxPreset !? { ~fxPreset.(\dream) };
    ~reload.value;
    ~playActive !? { ~playActive.value } ?? { ~allSeqs.do { |k| Pdef(k).play } };
    ~enableHarmony.(\counter);
    60.wait;

    "[I06 1:00] amen jazzy...".postln;
    ~kickSteps  = [1,0,0,0, 0,0,1,0, 0,0,1,0, 1,0,0,0]; ~kickAmp = 0.48;
    ~kickFreq = 52; ~kickPitchAmt = 3.5; ~kickDecay = 0.22; ~kickClick = 0.22;
    ~snareSteps = [0,0,0,0, 1,0,0,1, 0,0,0,0, 1,0,1,0]; ~snareAmp = 0.45;
    ~snareFreq = 240; ~snareNoiseAmt = 0.7; ~snareDecay = 0.10;
    ~hatSteps = [1,1,1,0, 0,1,1,1, 1,1,1,0, 0,1,1,1]; ~hatAmp = 0.11;
    ~percInst = \rim; ~percSteps = [0,0,1,0, 0,0,0,1, 0,0,1,0, 0,0,0,0];
    ~percAmp = 0.16;
    ~reload.value;
    90.wait;

    "[I06 2:30] fmLead jazzy...".postln;
    ~melodyInst = \fmLead;
    ~melodyAttack = 0.01; ~melodyRelease = 0.5; ~melodyCutoff = 4500;
    ~melodyAmp = 0.18;
    ~reload.value;
    24.do { |k|
        if (0.22.coin) {
            ~melodyNotes = ~genMelody.(0.55,
                [~scaleDorian, ~scaleMinorPent, ~scaleBlues].choose);
            ~reload.value;
        };
        5.wait;
    };

    "[I06 4:30] outro...".postln;
    ~melodyInst = \rhodes;
    ~melodyAttack = 0.02; ~melodyRelease = 1.2;
    ~reload.value;
    30.do { |k|
        var x = 1 - ((k + 1) / 30);
        ~kickAmp = x * 0.48; ~snareAmp = x * 0.45; ~hatAmp = x * 0.11;
        ~percAmp = x * 0.16; ~melodyAmp = x * 0.20;
        ~reload.value; 1.wait;
    };
    [\kickSeq, \hatSeq, \snareSeq, \clapSeq, \percSeq, \acidSeq, \melodySeq, \harmonySeq].do { |k| Pdef(k).stop };
    ~fxPreset !? { ~fxPreset.(\dry) };
    "[I06 5:00] === fin JAZZY BREAKS ===".postln;
}).play;
"=== TRACK I06 : JAZZY BREAKS 5 min lancee ===".postln;
)
