// =====================================================================
//  I10_deep_liquid.scd  --  Album I, track 10/15
// =====================================================================

// --- TRACK I10 : "DEEP LIQUID" 8 minutes -----------------------------
//   0:00 pad -> 1:00 rhodes -> 2:30 amen -> 4:00 sub -> 5:30 lead -> 7:30 outro
(
~track !? { ~track.stop };
~track = Routine({
    ~trackBegin !? { ~trackBegin.value };
    "[I10 0:00] vocalPad deep...".postln;
    ~bpm = 174;
    ~melodyInst = \vocalPad; ~melodyAttack = 0.5; ~melodyRelease = 1.8;
    ~melodyCutoff = 2500; ~melodyAmp = 0.20;
    ~melodyNotes = [60,0,0,0, 67,0,0,0, 72,0,0,0, 75,0,0,0,
                    72,0,0,0, 67,0,0,0, 65,0,0,0, 60,0,0,0];
    ~kickSteps=(0!16); ~hatSteps=(0!16); ~snareSteps=(0!16);
    ~clapSteps=(0!16); ~percSteps=(0!16); ~acidAmp=0;
    TempoClock.default.tempo = ~bpm/60;
    ~fxPreset !? { ~fxPreset.(\dream) };
    ~reload.value;
    ~playActive !? { ~playActive.value } ?? { ~allSeqs.do { |k| Pdef(k).play } };
    ~enableHarmony.(\fifth);
    60.wait;

    "[I10 1:00] rhodes liquid...".postln;
    ~melodyInst = \rhodes;
    ~melodyAttack = 0.01; ~melodyRelease = 0.7; ~melodyCutoff = 3500;
    ~melodyAmp = 0.20;
    ~melodyNotes = ~genMelody.(0.5, ~scaleMinorPent);
    ~reload.value;
    90.wait;

    "[I10 2:30] amen subtle...".postln;
    ~kickSteps  = [1,0,0,0, 0,0,1,0, 0,0,1,0, 1,0,0,0]; ~kickAmp = 0.48;
    ~kickFreq = 52; ~kickPitchAmt = 3.5; ~kickDecay = 0.20; ~kickClick = 0.22;
    ~snareSteps = [0,0,0,0, 1,0,0,0, 0,0,0,0, 1,0,0,1]; ~snareAmp = 0.45;
    ~snareFreq = 240; ~snareNoiseAmt = 0.7; ~snareDecay = 0.10;
    ~hatSteps = [1,1,1,1, 0,1,1,1, 1,1,1,1, 0,1,1,1]; ~hatAmp = 0.10;
    ~reload.value;
    90.wait;

    "[I10 4:00] subBoom deep...".postln;
    ~melodyInst = \subBoom;
    ~melodyAttack = 0.005; ~melodyRelease = 0.6; ~melodyCutoff = 800;
    ~melodyAmp = 0.25;
    ~melodyNotes = [36,0,0,0, 36,0,0,0, 39,0,0,0, 41,0,0,0,
                    36,0,0,0, 36,0,0,0, 41,0,0,0, 39,0,0,0];
    ~reload.value;
    90.wait;

    "[I10 5:30] fmLead -- variations...".postln;
    ~melodyInst = \fmLead;
    ~melodyAttack = 0.005; ~melodyRelease = 0.4; ~melodyCutoff = 5000;
    ~melodyAmp = 0.18;
    ~reload.value;
    24.do { |k|
        if (0.22.coin) {
            ~melodyNotes = ~genMelody.(0.55, ~scaleMinorPent);
            ~reload.value;
        };
        if (0.10.coin) { ~melodyNotes = ~octavate.(~melodyNotes, 0.2); ~reload.value };
        5.wait;
    };

    "[I10 7:30] outro...".postln;
    ~melodyInst = \warmPad;
    ~melodyAttack = 0.5; ~melodyRelease = 2.0;
    ~reload.value;
    30.do { |k|
        var x = 1 - ((k + 1) / 30);
        ~kickAmp = x * 0.48; ~snareAmp = x * 0.45; ~hatAmp = x * 0.10;
        ~melodyAmp = x * 0.20;
        ~reload.value; 1.wait;
    };
    [\kickSeq, \hatSeq, \snareSeq, \clapSeq, \percSeq, \acidSeq, \melodySeq, \harmonySeq].do { |k| Pdef(k).stop };
    ~fxPreset !? { ~fxPreset.(\dry) };
    "[I10 8:00] === fin DEEP LIQUID ===".postln;
}).play;
"=== TRACK I10 : DEEP LIQUID 8 min lancee ===".postln;
)
