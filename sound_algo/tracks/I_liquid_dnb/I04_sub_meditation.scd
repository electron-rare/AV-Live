// =====================================================================
//  I04_sub_meditation.scd  --  Album I, track 4/15
// =====================================================================

// --- TRACK I04 : "SUB MEDITATION" 7 minutes --------------------------
//   0:00 drone -> 1:00 amen subtle -> 2:30 sub -> 4:30 reese -> 6:30 outro
(
~track !? { ~track.stop };
~track = Routine({
    ~trackBegin !? { ~trackBegin.value };
    "[I04 0:00] drone meditatif...".postln;
    ~bpm = 174;
    ~melodyInst = \drone; ~melodyAttack = 1.0; ~melodyRelease = 2.5;
    ~melodyCutoff = 1500; ~melodyAmp = 0.18;
    ~melodyNotes = [48,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,
                    48,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0];
    ~kickSteps=(0!16); ~hatSteps=(0!16); ~snareSteps=(0!16);
    ~clapSteps=(0!16); ~percSteps=(0!16); ~acidAmp=0;
    TempoClock.default.tempo = ~bpm/60;
    ~fxPreset !? { ~fxPreset.(\space) };
    ~reload.value;
    ~playActive !? { ~playActive.value } ?? { ~allSeqs.do { |k| Pdef(k).play } };
    ~enableHarmony.(\bassline);
    60.wait;

    "[I04 1:00] amen subtle...".postln;
    ~kickSteps  = [1,0,0,0, 0,0,1,0, 0,0,1,0, 1,0,0,0]; ~kickAmp = 0.45;
    ~kickFreq = 50; ~kickPitchAmt = 3.5; ~kickDecay = 0.22; ~kickClick = 0.20;
    ~snareSteps = [0,0,0,0, 1,0,0,0, 0,0,0,0, 1,0,0,0]; ~snareAmp = 0.40;
    ~snareFreq = 240; ~snareNoiseAmt = 0.7; ~snareDecay = 0.10;
    ~hatSteps = [1,1,1,1, 0,1,1,1, 1,1,1,1, 0,1,1,1]; ~hatAmp = 0.08;
    ~reload.value;
    90.wait;

    "[I04 2:30] subBoom meditation...".postln;
    ~melodyInst = \subBoom;
    ~melodyAttack = 0.005; ~melodyRelease = 0.7; ~melodyCutoff = 700;
    ~melodyAmp = 0.28;
    ~melodyNotes = [36,0,0,0, 36,0,0,0, 39,0,0,0, 41,0,0,0,
                    36,0,0,0, 36,0,0,0, 41,0,0,0, 39,0,0,0];
    ~reload.value;
    120.wait;

    "[I04 4:30] reeseDnB rouler...".postln;
    ~melodyInst = \reeseDnB;
    ~melodyAttack = 0.005; ~melodyRelease = 0.4; ~melodyCutoff = 1200;
    ~melodyAmp = 0.22;
    ~vcfOn !? { ~vcfOn.(\ladder, 1500, 0.5) };
    ~lfoTo !? { ~lfoTo.(\melodyCutoff, 0.3, 1200, \sin, 2200) };
    ~reload.value;
    120.wait;

    "[I04 6:30] outro...".postln;
    ~vcfOff !? { ~vcfOff.() };
    ~lfoStopVar !? { ~lfoStopVar.(\melodyCutoff) };
    ~melodyInst = \drone;
    ~melodyAttack = 1.0; ~melodyRelease = 2.5;
    ~reload.value;
    30.do { |k|
        var x = 1 - ((k + 1) / 30);
        ~kickAmp = x * 0.45; ~snareAmp = x * 0.40; ~hatAmp = x * 0.08;
        ~melodyAmp = x * 0.22;
        ~reload.value; 1.wait;
    };
    [\kickSeq, \hatSeq, \snareSeq, \clapSeq, \percSeq, \acidSeq, \melodySeq, \harmonySeq].do { |k| Pdef(k).stop };
    ~fxPreset !? { ~fxPreset.(\dry) };
    "[I04 7:00] === fin SUB MEDITATION ===".postln;
}).play;
"=== TRACK I04 : SUB MEDITATION 7 min lancee ===".postln;
)
