// =====================================================================
//  H14_breakdown_climax.scd  --  Album H, track 14/15
// =====================================================================

// --- TRACK H14 : "BREAKDOWN CLIMAX" 5 minutes ------------------------
//   0:00 kick -> 1:00 build -> 1:30 break -> 2:30 drop -> 4:00 outro
(
~track !? { ~track.stop };
~track = Routine({
    ~trackBegin !? { ~trackBegin.value };
    "[H14 0:00] kick + acid intro...".postln;
    ~bpm = 142;
    ~kickSteps = [1,0,0,0, 1,0,0,0, 1,0,0,0, 1,0,0,0]; ~kickAmp = 0.55;
    ~kickFreq = 60; ~kickPitchAmt = 3.5; ~kickDecay = 0.25; ~kickClick = 0.20;
    ~hatSteps = [0,0,1,0, 0,0,1,0, 0,0,1,0, 0,0,1,0]; ~hatAmp = 0.16;
    ~clapSteps = [0,0,0,0, 1,0,0,0, 0,0,0,0, 1,0,0,0]; ~clapAmp = 0.30;
    ~snareSteps=(0!16); ~percSteps=(0!16);
    ~acidNotes = [36,36,48,36, 39,36,43,39, 36,41,36,39, 43,36,36,41];
    ~acidAccents = [1,0,0,0,1,0,1,0, 0,1,0,0,1,0,0,1];
    ~acidSlides = [0,0,1,0,0,0,0,1, 0,0,0,1,0,0,0,0];
    ~acidCutoff = 800; ~acidRq = 0.18; ~acidDrive = 2.5; ~acidAmp = 0.30;
    ~melodyInst = \warmPad; ~melodyAmp = 0.12;
    ~melodyNotes = [60,0,0,0, 67,0,0,0, 70,0,0,0, 72,0,0,0,
                    75,0,0,0, 72,0,0,0, 67,0,0,0, 60,0,0,0];
    TempoClock.default.tempo = ~bpm/60;
    ~fxPreset !? { ~fxPreset.(\trance) };
    ~reload.value;
    ~playActive !? { ~playActive.value } ?? { ~allSeqs.do { |k| Pdef(k).play } };
    ~enableHarmony.(\tranceLayer);
    60.wait;

    "[H14 1:00] BUILD 1...".postln;
    Synth(\riser, [\dur, 30, \startCutoff, 800, \endCutoff, 12000, \amp, 0.4]);
    30.do { |k|
        var x = (k + 1) / 30;
        ~acidCutoff = 800 + (x * 1500); ~hatAmp = 0.16 + (x * 0.05);
        ~reload.value; 1.wait;
    };

    "[H14 1:30] === BREAKDOWN ===".postln;
    Synth(\impact, [\freq, 38, \decay, 3, \amp, 0.7]);
    ~kickSteps=(0!16); ~hatAmp=0.05; ~clapSteps=(0!16); ~acidAmp = 0;
    ~melodyInst = \choir;
    ~melodyAttack = 0.5; ~melodyRelease = 1.8; ~melodyCutoff = 2800;
    ~melodyAmp = 0.22;
    ~reload.value;
    60.wait;

    "[H14 2:30] === DROP supersaw ===".postln;
    Synth(\riser, [\dur, 8, \startCutoff, 800, \endCutoff, 13000, \amp, 0.5]);
    8.wait;
    Synth(\impact, [\freq, 38, \decay, 3, \amp, 0.8]);
    ~kickSteps = [1,0,0,0, 1,0,0,0, 1,0,0,0, 1,0,0,0];
    ~hatSteps = [0,0,1,0, 0,0,1,0, 0,0,1,0, 0,0,1,0]; ~hatAmp = 0.18;
    ~clapSteps = [0,0,0,0, 1,0,0,0, 0,0,0,0, 1,0,0,0];
    ~acidAmp = 0.35; ~acidCutoff = 1800;
    ~melodyInst = \supersaw;
    ~melodyAttack = 0.005; ~melodyRelease = 0.4; ~melodyCutoff = 5500;
    ~melodyAmp = 0.22;
    ~vcfOn !? { ~vcfOn.(\moog, 2500, 0.4) };
    ~reload.value;
    82.wait;

    "[H14 4:00] outro...".postln;
    ~vcfOff !? { ~vcfOff.() };
    ~melodyInst = \warmPad;
    ~melodyAttack = 0.6; ~melodyRelease = 2.5;
    ~reload.value;
    30.do { |k|
        var x = 1 - ((k + 1) / 30);
        ~kickAmp = x * 0.55; ~hatAmp = x * 0.18; ~clapAmp = x * 0.30;
        ~acidAmp = x * 0.35; ~melodyAmp = x * 0.22;
        ~reload.value; 1.wait;
    };
    [\kickSeq, \hatSeq, \snareSeq, \clapSeq, \percSeq, \acidSeq, \melodySeq, \harmonySeq].do { |k| Pdef(k).stop };
    ~fxPreset !? { ~fxPreset.(\dry) };
    "[H14 4:30] === fin BREAKDOWN CLIMAX ===".postln;
}).play;
"=== TRACK H14 : BREAKDOWN CLIMAX 5 min lancee ===".postln;
)
