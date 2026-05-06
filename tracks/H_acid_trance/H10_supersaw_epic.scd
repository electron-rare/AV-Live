// =====================================================================
//  H10_supersaw_epic.scd  --  Album H, track 10/15
// =====================================================================

// --- TRACK H10 : "SUPERSAW EPIC" 8 minutes ---------------------------
//   0:00 pad -> 1:00 kick -> 2:00 supersaw -> 4:00 break -> 5:00 climax -> 7:30 outro
(
~track !? { ~track.stop };
~track = Routine({
    ~trackBegin !? { ~trackBegin.value };
    "[H10 0:00] pad epic...".postln;
    ~bpm = 140;
    ~melodyInst = \warmPad; ~melodyAttack = 0.6; ~melodyRelease = 2.0;
    ~melodyCutoff = 1800; ~melodyAmp = 0.18;
    ~melodyNotes = [60,0,0,0, 67,0,0,0, 72,0,0,0, 75,0,0,0,
                    77,0,0,0, 75,0,0,0, 72,0,0,0, 67,0,0,0];
    ~kickSteps=(0!16); ~hatSteps=(0!16); ~clapSteps=(0!16);
    ~acidNotes = [36,36,48,36, 39,36,43,39, 36,41,36,39, 43,36,36,41];
    ~acidAccents = [1,0,0,0,1,0,1,0, 0,1,0,0,1,0,0,1];
    ~acidSlides = [0,0,1,0,0,0,0,1, 0,0,0,1,0,0,0,0];
    ~acidCutoff = 600; ~acidRq = 0.18; ~acidDrive = 2.5; ~acidAmp = 0;
    TempoClock.default.tempo = ~bpm/60;
    ~fxPreset !? { ~fxPreset.(\trance) };
    ~reload.value;
    ~playActive !? { ~playActive.value } ?? { ~allSeqs.do { |k| Pdef(k).play } };
    ~enableHarmony.(\tranceLayer);
    60.wait;

    "[H10 1:00] kick + acid...".postln;
    ~kickSteps = [1,0,0,0, 1,0,0,0, 1,0,0,0, 1,0,0,0]; ~kickAmp = 0.55;
    ~kickFreq = 60; ~kickPitchAmt = 3.5; ~kickDecay = 0.25; ~kickClick = 0.22;
    ~hatSteps = [0,0,1,0, 0,0,1,0, 0,0,1,0, 0,0,1,0]; ~hatAmp = 0.16;
    ~clapSteps = [0,0,0,0, 1,0,0,0, 0,0,0,0, 1,0,0,0]; ~clapAmp = 0.32;
    ~acidAmp = 0.30;
    ~reload.value;
    60.wait;

    "[H10 2:00] supersaw epic anthem...".postln;
    ~melodyInst = \supersaw;
    ~melodyAttack = 0.005; ~melodyRelease = 0.4; ~melodyCutoff = 5000;
    ~melodyAmp = 0.22;
    ~melodyNotes = [60,67,72,77, 75,72,67,72, 65,72,77,79, 77,75,72,67,
                    63,70,75,79, 77,75,70,67, 67,72,77,79, 75,72,67,60];
    ~vcfOn !? { ~vcfOn.(\moog, 2500, 0.4) };
    ~lfoTo !? { ~lfoTo.(\melodyCutoff, 0.2, 2500, \sin, 5000) };
    ~reload.value;
    120.wait;

    "[H10 4:00] break -- choir + sub...".postln;
    ~vcfOff !? { ~vcfOff.() };
    ~lfoStopVar !? { ~lfoStopVar.(\melodyCutoff) };
    ~kickSteps=(0!16); ~hatAmp=0.05; ~clapSteps=(0!16); ~acidAmp = 0;
    ~melodyInst = \choir;
    ~melodyAttack = 0.5; ~melodyRelease = 1.8;
    ~melodyAmp = 0.22;
    ~reload.value;
    60.wait;

    "[H10 5:00] climax FINAL...".postln;
    Synth(\riser, [\dur, 16, \startCutoff, 800, \endCutoff, 13000, \amp, 0.5]);
    16.wait;
    Synth(\impact, [\freq, 38, \decay, 3, \amp, 0.7]);
    ~kickSteps = [1,0,0,0, 1,0,0,0, 1,0,0,0, 1,0,0,0];
    ~hatSteps = [0,0,1,0, 0,0,1,0, 0,0,1,0, 0,0,1,0]; ~hatAmp = 0.20;
    ~clapSteps = [0,0,0,0, 1,0,0,0, 0,0,0,0, 1,0,0,0];
    ~acidAmp = 0.35; ~acidCutoff = 2000;
    ~melodyInst = \supersaw;
    ~melodyAttack = 0.005; ~melodyRelease = 0.4; ~melodyCutoff = 5500;
    ~melodyAmp = 0.24;
    ~vcfOn !? { ~vcfOn.(\moog, 2800, 0.4) };
    ~reload.value;
    134.wait;

    "[H10 7:30] outro grand fade...".postln;
    ~vcfOff !? { ~vcfOff.() };
    ~melodyInst = \warmPad;
    ~melodyAttack = 0.6; ~melodyRelease = 2.5;
    ~reload.value;
    30.do { |k|
        var x = 1 - ((k + 1) / 30);
        ~kickAmp = x * 0.55; ~hatAmp = x * 0.20; ~clapAmp = x * 0.32;
        ~acidAmp = x * 0.35; ~melodyAmp = x * 0.24;
        ~reload.value; 1.wait;
    };
    [\kickSeq, \hatSeq, \snareSeq, \clapSeq, \percSeq, \acidSeq, \melodySeq, \harmonySeq].do { |k| Pdef(k).stop };
    ~fxPreset !? { ~fxPreset.(\dry) };
    "[H10 8:00] === fin SUPERSAW EPIC ===".postln;
}).play;
"=== TRACK H10 : SUPERSAW EPIC 8 min lancee ===".postln;
)
