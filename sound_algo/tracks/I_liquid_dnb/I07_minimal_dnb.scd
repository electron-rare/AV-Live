// =====================================================================
//  I07_minimal_dnb.scd  --  Album I, track 7/15
// =====================================================================

// --- TRACK I07 : "MINIMAL DNB" 5 minutes -----------------------------
//   0:00 amen direct -> 1:00 sub -> 3:00 lead -> 4:00 outro
(
~track !? { ~track.stop };
~track = Routine({
    ~trackBegin !? { ~trackBegin.value };
    "[I07 0:00] amen minimal direct...".postln;
    ~bpm = 174;
    ~kickSteps  = [1,0,0,0, 0,0,1,0, 0,0,1,0, 1,0,0,0]; ~kickAmp = 0.50;
    ~kickFreq = 55; ~kickPitchAmt = 3.5; ~kickDecay = 0.20; ~kickClick = 0.25;
    ~snareSteps = [0,0,0,0, 1,0,0,0, 0,0,0,0, 1,0,0,1]; ~snareAmp = 0.50;
    ~snareFreq = 240; ~snareNoiseAmt = 0.7; ~snareDecay = 0.10;
    ~hatSteps = [1,0,1,0, 0,1,1,1, 1,0,1,0, 0,1,1,1]; ~hatAmp = 0.10;
    ~clapSteps=(0!16); ~percSteps=(0!16); ~acidAmp=0;
    ~melodyInst = \warmPad; ~melodyAmp = 0.10;
    ~melodyNotes = [60,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,
                    63,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0];
    TempoClock.default.tempo = ~bpm/60;
    ~fxPreset !? { ~fxPreset.(\dub) };
    ~reload.value;
    ~playActive !? { ~playActive.value } ?? { ~allSeqs.do { |k| Pdef(k).play } };
    ~enableHarmony.(\bassline);
    60.wait;

    "[I07 1:00] subBoom minimal...".postln;
    ~melodyInst = \subBoom;
    ~melodyAttack = 0.005; ~melodyRelease = 0.6; ~melodyCutoff = 700;
    ~melodyAmp = 0.25;
    ~melodyNotes = [36,0,0,0, 36,0,0,0, 39,0,0,0, 41,0,0,0,
                    36,0,0,0, 36,0,0,0, 41,0,0,0, 39,0,0,0];
    ~reload.value;
    120.wait;

    "[I07 3:00] fmLead doux...".postln;
    ~melodyInst = \fmLead;
    ~melodyAttack = 0.01; ~melodyRelease = 0.4; ~melodyCutoff = 4500;
    ~melodyAmp = 0.18;
    ~melodyNotes = ~genMelody.(0.5, ~scaleMinorPent);
    ~reload.value;
    12.do { |k|
        if (0.20.coin) {
            ~melodyNotes = ~mutate.(~melodyNotes, 0.25, ~scaleMinorPent);
            ~reload.value;
        };
        5.wait;
    };

    "[I07 4:00] outro...".postln;
    ~melodyInst = \warmPad;
    ~melodyAttack = 0.5; ~melodyRelease = 2.0;
    ~reload.value;
    30.do { |k|
        var x = 1 - ((k + 1) / 30);
        ~kickAmp = x * 0.50; ~snareAmp = x * 0.50; ~hatAmp = x * 0.10;
        ~melodyAmp = x * 0.18;
        ~reload.value; 1.wait;
    };
    [\kickSeq, \hatSeq, \snareSeq, \clapSeq, \percSeq, \acidSeq, \melodySeq, \harmonySeq].do { |k| Pdef(k).stop };
    ~fxPreset !? { ~fxPreset.(\dry) };
    "[I07 4:30] === fin MINIMAL DNB ===".postln;
}).play;
"=== TRACK I07 : MINIMAL DNB 5 min lancee ===".postln;
)
