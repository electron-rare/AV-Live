// =====================================================================
//  I13_techstep_minimal.scd  --  Album I, track 13/15
// =====================================================================

// --- TRACK I13 : "TECHSTEP MINIMAL" 4 minutes ------------------------
//   0:00 amen tight -> 1:00 reese -> 3:00 outro
(
~track !? { ~track.stop };
~track = Routine({
    ~trackBegin !? { ~trackBegin.value };
    "[I13 0:00] amen tight techstep...".postln;
    ~bpm = 174;
    ~kickSteps  = [1,0,0,0, 0,0,1,0, 1,0,1,0, 0,0,0,0]; ~kickAmp = 0.55;
    ~kickFreq = 58; ~kickPitchAmt = 4.0; ~kickDecay = 0.18; ~kickClick = 0.32;
    ~snareSteps = [0,0,0,0, 1,0,0,0, 0,0,0,0, 1,0,0,0]; ~snareAmp = 0.55;
    ~snareFreq = 260; ~snareNoiseAmt = 0.8; ~snareDecay = 0.08;
    ~hatSteps = [1,0,1,0, 0,1,1,1, 1,0,1,0, 0,1,1,1]; ~hatAmp = 0.13;
    ~clapSteps=(0!16); ~percSteps=(0!16); ~acidAmp=0;
    ~melodyInst = \drone; ~melodyAmp = 0.10;
    ~melodyNotes = [36,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,
                    36,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0];
    TempoClock.default.tempo = ~bpm/60;
    ~fxPreset !? { ~fxPreset.(\industrial) };
    ~reload.value;
    ~playActive !? { ~playActive.value } ?? { ~allSeqs.do { |k| Pdef(k).play } };
    ~enableHarmony.(\bassline);
    60.wait;

    "[I13 1:00] reese minimal...".postln;
    ~melodyInst = \reese;
    ~melodyAttack = 0.005; ~melodyRelease = 0.3; ~melodyCutoff = 1200;
    ~melodyAmp = 0.22;
    ~melodyNotes = [36,0,0,0, 36,0,0,0, 39,0,0,0, 41,0,0,0,
                    36,0,0,0, 36,0,0,0, 41,0,0,0, 39,0,0,0];
    ~vcfOn !? { ~vcfOn.(\ladder, 1500, 0.5) };
    ~lfoTo !? { ~lfoTo.(\melodyCutoff, 0.4, 1200, \saw, 2200) };
    ~reload.value;
    24.do { |k|
        if (0.20.coin) {
            ~melodyNotes = ~mutate.(~melodyNotes, 0.25, ~scaleMinor);
            ~reload.value;
        };
        5.wait;
    };

    "[I13 3:00] outro...".postln;
    ~vcfOff !? { ~vcfOff.() };
    ~lfoStopVar !? { ~lfoStopVar.(\melodyCutoff) };
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
    "[I13 3:30] === fin TECHSTEP MINIMAL ===".postln;
}).play;
"=== TRACK I13 : TECHSTEP MINIMAL 4 min lancee ===".postln;
)
