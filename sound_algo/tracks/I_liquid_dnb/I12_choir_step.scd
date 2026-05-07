// =====================================================================
//  I12_choir_step.scd  --  Album I, track 12/15
// =====================================================================

// --- TRACK I12 : "CHOIR STEP" 5 minutes ------------------------------
//   0:00 choir -> 1:00 amen -> 2:30 lead -> 4:00 outro
(
~track !? { ~track.stop };
~track = Routine({
    ~trackBegin !? { ~trackBegin.value };
    "[I12 0:00] choir intro...".postln;
    ~bpm = 174;
    ~melodyInst = \choir; ~melodyAttack = 0.5; ~melodyRelease = 1.8;
    ~melodyCutoff = 2800; ~melodyAmp = 0.22;
    ~melodyNotes = [60,0,0,0, 65,0,0,0, 67,0,0,0, 72,0,0,0,
                    70,0,0,0, 67,0,0,0, 65,0,0,0, 60,0,0,0];
    ~kickSteps=(0!16); ~hatSteps=(0!16); ~snareSteps=(0!16); ~acidAmp=0;
    TempoClock.default.tempo = ~bpm/60;
    ~fxPreset !? { ~fxPreset.(\space) };
    ~reload.value;
    ~playActive !? { ~playActive.value } ?? { ~allSeqs.do { |k| Pdef(k).play } };
    ~enableHarmony.(\fifth);
    60.wait;

    "[I12 1:00] amen + choir layered...".postln;
    ~kickSteps  = [1,0,0,0, 0,0,1,0, 0,0,1,0, 1,0,0,0]; ~kickAmp = 0.48;
    ~kickFreq = 52; ~kickPitchAmt = 3.5; ~kickDecay = 0.22; ~kickClick = 0.22;
    ~snareSteps = [0,0,0,0, 1,0,0,0, 0,0,0,0, 1,0,0,1]; ~snareAmp = 0.45;
    ~snareFreq = 240; ~snareNoiseAmt = 0.7; ~snareDecay = 0.10;
    ~hatSteps = [1,1,1,1, 0,1,1,1, 1,1,1,1, 0,1,1,1]; ~hatAmp = 0.10;
    ~reload.value;
    90.wait;

    "[I12 2:30] fmLead -- variations...".postln;
    ~melodyInst = \fmLead;
    ~melodyAttack = 0.005; ~melodyRelease = 0.4; ~melodyCutoff = 5000;
    ~melodyAmp = 0.18;
    ~melodyNotes = ~genMelody.(0.55, ~scaleMinor);
    ~reload.value;
    18.do { |k|
        if (0.22.coin) {
            ~melodyNotes = ~mutate.(~melodyNotes, 0.25, ~scaleMinor);
            ~reload.value;
        };
        5.wait;
    };

    "[I12 4:00] outro choir fade...".postln;
    ~melodyInst = \choir;
    ~melodyAttack = 0.5; ~melodyRelease = 2.0;
    ~reload.value;
    30.do { |k|
        var x = 1 - ((k + 1) / 30);
        ~kickAmp = x * 0.48; ~snareAmp = x * 0.45; ~hatAmp = x * 0.10;
        ~melodyAmp = x * 0.22;
        ~reload.value; 1.wait;
    };
    [\kickSeq, \hatSeq, \snareSeq, \clapSeq, \percSeq, \acidSeq, \melodySeq, \harmonySeq].do { |k| Pdef(k).stop };
    ~fxPreset !? { ~fxPreset.(\dry) };
    "[I12 4:30] === fin CHOIR STEP ===".postln;
}).play;
"=== TRACK I12 : CHOIR STEP 5 min lancee ===".postln;
)
