// =====================================================================
//  I15_liquid_finale.scd  --  Album I, track 15/15
// =====================================================================

// --- TRACK I15 : "LIQUID FINALE" 6 minutes ---------------------------
//   0:00 pad -> 1:00 rhodes -> 2:00 amen -> 3:30 sub + lead -> 5:00 outro
(
~track !? { ~track.stop };
~track = Routine({
    ~trackBegin !? { ~trackBegin.value };
    "[I15 0:00] vocalPad finale...".postln;
    ~bpm = 174;
    ~melodyInst = \vocalPad; ~melodyAttack = 0.5; ~melodyRelease = 1.8;
    ~melodyCutoff = 2500; ~melodyAmp = 0.20;
    ~melodyNotes = [60,0,0,0, 67,0,0,0, 72,0,0,0, 75,0,0,0,
                    72,0,0,0, 67,0,0,0, 65,0,0,0, 60,0,0,0];
    ~kickSteps=(0!16); ~hatSteps=(0!16); ~snareSteps=(0!16); ~acidAmp=0;
    TempoClock.default.tempo = ~bpm/60;
    ~fxPreset !? { ~fxPreset.(\dream) };
    ~reload.value;
    ~playActive !? { ~playActive.value } ?? { ~allSeqs.do { |k| Pdef(k).play } };
    ~enableHarmony.(\fifth);
    60.wait;

    "[I15 1:00] rhodes liquid...".postln;
    ~melodyInst = \rhodes;
    ~melodyAttack = 0.01; ~melodyRelease = 0.7; ~melodyCutoff = 3500;
    ~melodyAmp = 0.20;
    ~melodyNotes = ~genMelody.(0.55, ~scaleMinorPent);
    ~reload.value;
    60.wait;

    "[I15 2:00] amen entre...".postln;
    ~kickSteps  = [1,0,0,0, 0,0,1,0, 0,0,1,0, 1,0,0,0]; ~kickAmp = 0.50;
    ~kickFreq = 52; ~kickPitchAmt = 3.5; ~kickDecay = 0.20; ~kickClick = 0.25;
    ~snareSteps = [0,0,0,0, 1,0,0,0, 0,0,0,0, 1,0,0,1]; ~snareAmp = 0.48;
    ~snareFreq = 240; ~snareNoiseAmt = 0.7; ~snareDecay = 0.10;
    ~hatSteps = [1,1,1,1, 0,1,1,1, 1,1,1,1, 0,1,1,1]; ~hatAmp = 0.12;
    ~reload.value;
    90.wait;

    "[I15 3:30] subBoom + fmLead...".postln;
    ~melodyInst = \fmLead;
    ~melodyAttack = 0.005; ~melodyRelease = 0.4; ~melodyCutoff = 5000;
    ~melodyAmp = 0.20;
    ~vcfOn !? { ~vcfOn.(\moog, 2500, 0.4) };
    ~lfoTo !? { ~lfoTo.(\melodyCutoff, 0.2, 3000, \sin, 5000) };
    ~melodyNotes = [60,0,67,0, 72,0,67,0, 65,0,72,0, 75,0,70,0,
                    63,0,67,0, 70,0,67,0, 60,0,65,0, 63,0,60,0];
    ~reload.value;
    90.wait;

    "[I15 5:00] outro grand fade...".postln;
    ~vcfOff !? { ~vcfOff.() };
    ~lfoStopVar !? { ~lfoStopVar.(\melodyCutoff) };
    ~melodyInst = \vocalPad;
    ~melodyAttack = 0.6; ~melodyRelease = 2.5;
    ~reload.value;
    60.do { |k|
        var x = 1 - ((k + 1) / 60);
        ~kickAmp = x * 0.50; ~snareAmp = x * 0.48; ~hatAmp = x * 0.12;
        ~melodyAmp = x * 0.20;
        ~reload.value; 1.wait;
    };
    [\kickSeq, \hatSeq, \snareSeq, \clapSeq, \percSeq, \acidSeq, \melodySeq, \harmonySeq].do { |k| Pdef(k).stop };
    ~fxPreset !? { ~fxPreset.(\dry) };
    "[I15 6:00] === fin LIQUID FINALE ===".postln;
}).play;
"=== TRACK I15 : LIQUID FINALE 6 min lancee ===".postln;
)
