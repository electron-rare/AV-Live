// =====================================================================
//  H05_uplifting_303.scd  --  Album H, track 5/15
// =====================================================================

// --- TRACK H05 : "UPLIFTING 303" 8 minutes ---------------------------
//   0:00 pad -> 1:00 kick -> 2:00 build -> 2:30 drop -> 4:30 break -> 5:30 climax -> 7:30 outro
(
~track !? { ~track.stop };
~track = Routine({
    ~trackBegin !? { ~trackBegin.value };
    "[H05 0:00] pad uplifting...".postln;
    ~bpm = 138;
    ~melodyInst = \warmPad; ~melodyAttack = 0.6; ~melodyRelease = 2.0;
    ~melodyCutoff = 1800; ~melodyAmp = 0.16;
    ~melodyNotes = [60,0,0,0, 67,0,0,0, 72,0,0,0, 75,0,0,0,
                    77,0,0,0, 75,0,0,0, 72,0,0,0, 67,0,0,0];
    ~kickSteps=(0!16); ~hatSteps=(0!16); ~clapSteps=(0!16);
    ~acidNotes = [36,36,48,36, 41,36,43,41, 36,41,36,39, 43,36,36,41];
    ~acidAccents = [1,0,0,0,1,0,1,0, 0,1,0,0,1,0,0,1];
    ~acidSlides = [0,0,1,0,0,0,0,1, 0,0,0,1,0,0,0,0];
    ~acidCutoff = 600; ~acidRq = 0.18; ~acidDrive = 2.5; ~acidAmp = 0;
    TempoClock.default.tempo = ~bpm/60;
    ~fxPreset !? { ~fxPreset.(\trance) };
    ~reload.value;
    ~playActive !? { ~playActive.value } ?? { ~allSeqs.do { |k| Pdef(k).play } };
    ~enableHarmony.(\tranceLayer);
    60.wait;

    "[H05 1:00] kick + acid...".postln;
    ~kickSteps = [1,0,0,0, 1,0,0,0, 1,0,0,0, 1,0,0,0]; ~kickAmp = 0.55;
    ~kickFreq = 60; ~kickPitchAmt = 3.5; ~kickDecay = 0.25; ~kickClick = 0.20;
    ~hatSteps = [0,0,1,0, 0,0,1,0, 0,0,1,0, 0,0,1,0]; ~hatAmp = 0.16;
    ~clapSteps = [0,0,0,0, 1,0,0,0, 0,0,0,0, 1,0,0,0]; ~clapAmp = 0.32;
    ~acidAmp = 0.30;
    ~reload.value;
    60.wait;

    "[H05 2:00] BUILD...".postln;
    Synth(\riser, [\dur, 30, \startCutoff, 500, \endCutoff, 13000, \amp, 0.4]);
    30.do { |k|
        var x = (k + 1) / 30;
        ~acidCutoff = 600 + (x * 2200); ~acidRq = 0.18 - (x * 0.12);
        ~reload.value; 1.wait;
    };

    "[H05 2:30] === DROP supersaw ===".postln;
    Synth(\impact, [\freq, 40, \decay, 3, \amp, 0.7]);
    ~melodyInst = \supersaw;
    ~melodyAttack = 0.003; ~melodyRelease = 0.3; ~melodyCutoff = 5500;
    ~melodyAmp = 0.20;
    ~melodyNotes = [60,67,72,77, 75,72,67,72, 65,72,77,79, 77,75,72,67,
                    63,70,75,79, 77,75,70,67, 67,72,77,79, 75,72,67,60];
    ~vcfOn !? { ~vcfOn.(\moog, 2500, 0.4) };
    ~reload.value;
    120.wait;

    "[H05 4:30] breakdown -- choir...".postln;
    ~vcfOff !? { ~vcfOff.() };
    ~kickSteps=(0!16); ~hatAmp=0.05; ~clapSteps=(0!16); ~acidAmp = 0;
    ~melodyInst = \choir;
    ~melodyAttack = 0.4; ~melodyRelease = 1.5; ~melodyCutoff = 2800;
    ~melodyAmp = 0.22;
    ~reload.value;
    60.wait;

    "[H05 5:30] climax FINAL...".postln;
    Synth(\riser, [\dur, 8, \startCutoff, 1000, \endCutoff, 13000, \amp, 0.5]);
    8.wait;
    Synth(\impact, [\freq, 38, \decay, 3, \amp, 0.7]);
    ~kickSteps = [1,0,0,0, 1,0,0,0, 1,0,0,0, 1,0,0,0];
    ~hatSteps = [0,0,1,0, 0,0,1,0, 0,0,1,0, 0,0,1,0]; ~hatAmp = 0.18;
    ~clapSteps = [0,0,0,0, 1,0,0,0, 0,0,0,0, 1,0,0,0];
    ~acidAmp = 0.35; ~acidCutoff = 2000;
    ~melodyInst = \hardLead;
    ~melodyAttack = 0.002; ~melodyRelease = 0.25; ~melodyCutoff = 6000;
    ~melodyAmp = 0.22;
    ~reload.value;
    112.wait;

    "[H05 7:30] outro...".postln;
    ~melodyInst = \warmPad;
    ~melodyAttack = 0.6; ~melodyRelease = 2.5;
    ~reload.value;
    30.do { |k|
        var x = 1 - ((k + 1) / 30);
        ~kickAmp = x * 0.55; ~hatAmp = x * 0.18; ~clapAmp = x * 0.32;
        ~acidAmp = x * 0.35; ~melodyAmp = x * 0.22;
        ~reload.value; 1.wait;
    };
    [\kickSeq, \hatSeq, \snareSeq, \clapSeq, \percSeq, \acidSeq, \melodySeq, \harmonySeq].do { |k| Pdef(k).stop };
    ~fxPreset !? { ~fxPreset.(\dry) };
    "[H05 8:00] === fin UPLIFTING 303 ===".postln;
}).play;
"=== TRACK H05 : UPLIFTING 303 8 min lancee ===".postln;
)
