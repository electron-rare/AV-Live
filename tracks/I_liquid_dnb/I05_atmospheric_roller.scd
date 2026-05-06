// =====================================================================
//  I05_atmospheric_roller.scd  --  Album I, track 5/15
// =====================================================================

// --- TRACK I05 : "ATMOSPHERIC ROLLER" 8 minutes ----------------------
//   0:00 pad -> 1:00 amen -> 2:30 fmLead -> 4:30 break -> 5:30 reese -> 7:30 outro
(
~track !? { ~track.stop };
~track = Routine({
    ~trackBegin !? { ~trackBegin.value };
    "[I05 0:00] vocalPad atmosphere...".postln;
    ~bpm = 174;
    ~melodyInst = \vocalPad; ~melodyAttack = 0.5; ~melodyRelease = 1.8;
    ~melodyCutoff = 2500; ~melodyAmp = 0.18;
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

    "[I05 1:00] amen roller...".postln;
    ~kickSteps  = [1,0,0,0, 0,0,1,0, 0,0,1,0, 1,0,0,0]; ~kickAmp = 0.50;
    ~kickFreq = 55; ~kickPitchAmt = 3.5; ~kickDecay = 0.20; ~kickClick = 0.25;
    ~snareSteps = [0,0,0,0, 1,0,0,0, 0,0,0,0, 1,0,0,1]; ~snareAmp = 0.50;
    ~snareFreq = 240; ~snareNoiseAmt = 0.7; ~snareDecay = 0.10;
    ~hatSteps = [1,1,1,1, 0,1,1,1, 1,1,1,1, 0,1,1,1]; ~hatAmp = 0.12;
    ~reload.value;
    90.wait;

    "[I05 2:30] fmLead lead...".postln;
    ~melodyInst = \fmLead;
    ~melodyAttack = 0.005; ~melodyRelease = 0.4; ~melodyCutoff = 5000;
    ~melodyAmp = 0.18;
    ~melodyNotes = ~genMelody.(0.55, ~scaleMinorPent);
    ~reload.value;
    24.do { |k|
        if (0.22.coin) {
            ~melodyNotes = ~mutate.(~melodyNotes, 0.25, ~scaleMinorPent);
            ~reload.value;
        };
        5.wait;
    };

    "[I05 4:30] break vocalPad...".postln;
    ~kickSteps=(0!16); ~snareSteps=(0!16); ~hatAmp=0.06;
    ~melodyInst = \vocalPad;
    ~melodyAttack = 0.5; ~melodyRelease = 1.8;
    ~melodyAmp = 0.22;
    ~reload.value;
    60.wait;

    "[I05 5:30] DROP -- reese...".postln;
    Synth(\impact, [\freq, 45, \decay, 2, \amp, 0.5]);
    ~kickSteps  = [1,0,0,0, 0,0,1,0, 0,0,1,0, 1,0,0,0];
    ~snareSteps = [0,0,0,0, 1,0,0,0, 0,0,0,0, 1,0,0,1];
    ~hatSteps = [1,1,1,1, 0,1,1,1, 1,1,1,1, 0,1,1,1]; ~hatAmp = 0.13;
    ~melodyInst = \reeseDnB;
    ~melodyAttack = 0.005; ~melodyRelease = 0.4; ~melodyCutoff = 1500;
    ~melodyAmp = 0.22;
    ~melodyNotes = [36,0,0,0, 36,0,0,0, 39,0,0,0, 41,0,0,0,
                    36,0,0,0, 36,0,0,0, 41,0,0,0, 39,0,0,0];
    ~vcfOn !? { ~vcfOn.(\ladder, 1500, 0.5) };
    ~reload.value;
    120.wait;

    "[I05 7:30] outro...".postln;
    ~vcfOff !? { ~vcfOff.() };
    ~melodyInst = \warmPad;
    ~melodyAttack = 0.5; ~melodyRelease = 2.0;
    ~reload.value;
    30.do { |k|
        var x = 1 - ((k + 1) / 30);
        ~kickAmp = x * 0.50; ~snareAmp = x * 0.50; ~hatAmp = x * 0.13;
        ~melodyAmp = x * 0.22;
        ~reload.value; 1.wait;
    };
    [\kickSeq, \hatSeq, \snareSeq, \clapSeq, \percSeq, \acidSeq, \melodySeq, \harmonySeq].do { |k| Pdef(k).stop };
    ~fxPreset !? { ~fxPreset.(\dry) };
    "[I05 8:00] === fin ATMOSPHERIC ROLLER ===".postln;
}).play;
"=== TRACK I05 : ATMOSPHERIC ROLLER 8 min lancee ===".postln;
)
