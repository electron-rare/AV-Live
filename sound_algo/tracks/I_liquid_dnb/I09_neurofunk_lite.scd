// =====================================================================
//  I09_neurofunk_lite.scd  --  Album I, track 9/15
// =====================================================================

// --- TRACK I09 : "NEUROFUNK LITE" 7 minutes --------------------------
//   0:00 pad -> 1:00 amen tight -> 2:30 reeseHard -> 4:30 lead -> 6:30 outro
(
~track !? { ~track.stop };
~track = Routine({
    ~trackBegin !? { ~trackBegin.value };
    "[I09 0:00] pad neurotech...".postln;
    ~bpm = 174;
    ~melodyInst = \drone; ~melodyAttack = 0.8; ~melodyRelease = 2.0;
    ~melodyCutoff = 1500; ~melodyAmp = 0.18;
    ~melodyNotes = [36,0,0,0, 0,0,0,0, 36,0,0,0, 39,0,0,0,
                    36,0,0,0, 0,0,0,0, 36,0,0,0, 41,0,0,0];
    ~kickSteps=(0!16); ~hatSteps=(0!16); ~snareSteps=(0!16); ~acidAmp=0;
    TempoClock.default.tempo = ~bpm/60;
    ~fxPreset !? { ~fxPreset.(\industrial) };
    ~reload.value;
    ~playActive !? { ~playActive.value } ?? { ~allSeqs.do { |k| Pdef(k).play } };
    ~enableHarmony.(\bassline);
    60.wait;

    "[I09 1:00] amen tight + clap...".postln;
    ~kickSteps  = [1,0,0,0, 0,0,1,0, 1,0,1,0, 0,0,0,0]; ~kickAmp = 0.55;
    ~kickFreq = 58; ~kickPitchAmt = 4.0; ~kickDecay = 0.18; ~kickClick = 0.32;
    ~snareSteps = [0,0,0,0, 1,0,0,0, 0,0,0,0, 1,0,1,0]; ~snareAmp = 0.55;
    ~snareFreq = 260; ~snareNoiseAmt = 0.8; ~snareDecay = 0.08;
    ~hatSteps = [1,1,1,1, 0,1,1,1, 1,1,1,1, 0,1,1,1]; ~hatAmp = 0.13;
    ~reload.value;
    90.wait;

    "[I09 2:30] reeseHard wobble...".postln;
    ~melodyInst = \reeseHard;
    ~melodyAttack = 0.005; ~melodyRelease = 0.3; ~melodyCutoff = 1200;
    ~melodyDrive = 2.5; ~melodyAmp = 0.22;
    ~melodyNotes = [36,0,0,0, 39,0,0,0, 41,0,0,0, 36,0,0,0,
                    36,0,0,0, 41,0,0,0, 43,0,0,0, 39,0,0,0];
    ~vcfOn !? { ~vcfOn.(\ladder, 1500, 0.55) };
    ~lfoTo !? { ~lfoTo.(\melodyCutoff, 0.35, 1200, \saw, 2200) };
    ~reload.value;
    120.wait;

    "[I09 4:30] hardLead techno...".postln;
    ~vcfOff !? { ~vcfOff.() };
    ~lfoStopVar !? { ~lfoStopVar.(\melodyCutoff) };
    ~melodyInst = \hardLead;
    ~melodyAttack = 0.003; ~melodyRelease = 0.2; ~melodyCutoff = 5000;
    ~melodyAmp = 0.20;
    ~melodyNotes = ~genMelody.(0.55, ~scaleMinor);
    ~reload.value;
    120.wait;

    "[I09 6:30] outro...".postln;
    ~melodyInst = \drone;
    ~melodyAttack = 0.8; ~melodyRelease = 2.0;
    ~reload.value;
    30.do { |k|
        var x = 1 - ((k + 1) / 30);
        ~kickAmp = x * 0.55; ~snareAmp = x * 0.55; ~hatAmp = x * 0.13;
        ~melodyAmp = x * 0.22;
        ~reload.value; 1.wait;
    };
    [\kickSeq, \hatSeq, \snareSeq, \clapSeq, \percSeq, \acidSeq, \melodySeq, \harmonySeq].do { |k| Pdef(k).stop };
    ~fxPreset !? { ~fxPreset.(\dry) };
    "[I09 7:00] === fin NEUROFUNK LITE ===".postln;
}).play;
"=== TRACK I09 : NEUROFUNK LITE 7 min lancee ===".postln;
)
