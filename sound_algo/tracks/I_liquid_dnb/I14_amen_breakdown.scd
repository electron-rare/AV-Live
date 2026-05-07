// =====================================================================
//  I14_amen_breakdown.scd  --  Album I, track 14/15
// =====================================================================

// --- TRACK I14 : "AMEN BREAKDOWN" 5 minutes --------------------------
//   0:00 amen -> 1:00 break -> 2:00 drop -> 4:00 outro
(
~track !? { ~track.stop };
~track = Routine({
    ~trackBegin !? { ~trackBegin.value };
    "[I14 0:00] amen + pad...".postln;
    ~bpm = 174;
    ~kickSteps  = [1,0,0,0, 0,0,1,0, 0,0,1,0, 1,0,0,0]; ~kickAmp = 0.52;
    ~kickFreq = 55; ~kickPitchAmt = 3.5; ~kickDecay = 0.20; ~kickClick = 0.25;
    ~snareSteps = [0,0,0,0, 1,0,0,0, 0,0,0,0, 1,0,0,1]; ~snareAmp = 0.50;
    ~snareFreq = 240; ~snareNoiseAmt = 0.7; ~snareDecay = 0.10;
    ~hatSteps = [1,1,1,1, 0,1,1,1, 1,1,1,1, 0,1,1,1]; ~hatAmp = 0.12;
    ~clapSteps=(0!16); ~percSteps=(0!16); ~acidAmp=0;
    ~melodyInst = \warmPad; ~melodyAmp = 0.14;
    ~melodyNotes = [60,0,0,0, 65,0,0,0, 67,0,0,0, 72,0,0,0,
                    70,0,0,0, 67,0,0,0, 65,0,0,0, 60,0,0,0];
    TempoClock.default.tempo = ~bpm/60;
    ~fxPreset !? { ~fxPreset.(\dub) };
    ~reload.value;
    ~playActive !? { ~playActive.value } ?? { ~allSeqs.do { |k| Pdef(k).play } };
    ~enableHarmony.(\bassline);
    60.wait;

    "[I14 1:00] BREAKDOWN choir...".postln;
    ~kickSteps=(0!16); ~snareSteps=(0!16); ~hatAmp=0.05;
    ~melodyInst = \choir;
    ~melodyAttack = 0.5; ~melodyRelease = 1.8; ~melodyCutoff = 2800;
    ~melodyAmp = 0.22;
    ~reload.value;
    60.wait;

    "[I14 2:00] === DROP amen + reese ===".postln;
    Synth(\impact, [\freq, 45, \decay, 2, \amp, 0.5]);
    ~kickSteps  = [1,0,0,0, 0,0,1,0, 0,0,1,0, 1,0,0,0];
    ~snareSteps = [0,0,0,0, 1,0,0,0, 0,0,0,0, 1,0,0,1];
    ~hatSteps = [1,1,1,1, 0,1,1,1, 1,1,1,1, 0,1,1,1]; ~hatAmp = 0.14;
    ~melodyInst = \reeseDnB;
    ~melodyAttack = 0.005; ~melodyRelease = 0.4; ~melodyCutoff = 1500;
    ~melodyAmp = 0.22;
    ~melodyNotes = [36,0,0,0, 36,0,0,0, 39,0,0,0, 41,0,0,0,
                    36,0,0,0, 36,0,0,0, 41,0,0,0, 39,0,0,0];
    ~vcfOn !? { ~vcfOn.(\ladder, 1500, 0.5) };
    ~reload.value;
    120.wait;

    "[I14 4:00] outro...".postln;
    ~vcfOff !? { ~vcfOff.() };
    ~melodyInst = \warmPad;
    ~melodyAttack = 0.5; ~melodyRelease = 2.0;
    ~reload.value;
    30.do { |k|
        var x = 1 - ((k + 1) / 30);
        ~kickAmp = x * 0.52; ~snareAmp = x * 0.50; ~hatAmp = x * 0.14;
        ~melodyAmp = x * 0.22;
        ~reload.value; 1.wait;
    };
    [\kickSeq, \hatSeq, \snareSeq, \clapSeq, \percSeq, \acidSeq, \melodySeq, \harmonySeq].do { |k| Pdef(k).stop };
    ~fxPreset !? { ~fxPreset.(\dry) };
    "[I14 4:30] === fin AMEN BREAKDOWN ===".postln;
}).play;
"=== TRACK I14 : AMEN BREAKDOWN 5 min lancee ===".postln;
)
