// =====================================================================
//  H03_303_ascension.scd  --  Album H, track 3/15
// =====================================================================

// --- TRACK H03 : "303 ASCENSION" 6 minutes ---------------------------
//   0:00 pad -> 1:00 kick -> 2:00 build acid -> 3:00 drop -> 4:30 climax -> 5:30 outro
(
~track !? { ~track.stop };
~track = Routine({
    ~trackBegin !? { ~trackBegin.value };
    "[H03 0:00] pad...".postln;
    ~bpm = 142;
    ~melodyInst = \warmPad; ~melodyAttack = 0.6; ~melodyRelease = 2.0;
    ~melodyCutoff = 1800; ~melodyAmp = 0.16;
    ~melodyNotes = [60,0,0,0,0,0,0,0, 63,0,0,0,0,0,0,0,
                    67,0,0,0,0,0,0,0, 70,0,0,0,0,0,0,0];
    ~kickSteps=(0!16); ~hatSteps=(0!16); ~clapSteps=(0!16);
    ~acidNotes = [36,36,48,36, 39,36,43,39, 36,41,36,39, 43,36,36,41];
    ~acidAccents = [1,0,0,0,1,0,1,0, 0,1,0,0,1,0,0,1];
    ~acidSlides = [0,0,1,0,0,0,0,1, 0,0,0,1,0,0,0,0];
    ~acidCutoff = 500; ~acidRq = 0.20; ~acidDrive = 2.5; ~acidAmp = 0;
    TempoClock.default.tempo = ~bpm/60;
    ~fxPreset !? { ~fxPreset.(\trance) };
    ~reload.value;
    ~playActive !? { ~playActive.value } ?? { ~allSeqs.do { |k| Pdef(k).play } };
    ~enableHarmony.(\tranceLayer);
    60.wait;

    "[H03 1:00] kick 4/4 + acid doux...".postln;
    ~kickSteps = [1,0,0,0, 1,0,0,0, 1,0,0,0, 1,0,0,0]; ~kickAmp = 0.55;
    ~kickFreq = 60; ~kickPitchAmt = 3.5; ~kickDecay = 0.25; ~kickClick = 0.20;
    ~hatSteps = [0,0,1,0, 0,0,1,0, 0,0,1,0, 0,0,1,0]; ~hatAmp = 0.15;
    ~clapSteps = [0,0,0,0, 1,0,0,0, 0,0,0,0, 1,0,0,0]; ~clapAmp = 0.30;
    ~acidAmp = 0.25;
    ~reload.value;
    60.wait;

    "[H03 2:00] BUILD acid ascension...".postln;
    Synth(\riser, [\dur, 32, \startCutoff, 500, \endCutoff, 12000, \amp, 0.3]);
    32.do { |k|
        var x = (k + 1) / 32;
        ~acidCutoff = 500 + (x * 2000); ~acidRq = 0.20 - (x * 0.12);
        ~hatAmp = 0.15 + (x * 0.06);
        ~reload.value; 1.wait;
    };

    "[H03 3:00] === DROP ===".postln;
    Synth(\impact, [\freq, 40, \decay, 2.5, \amp, 0.6]);
    ~melodyInst = \squareLead;
    ~melodyAttack = 0.002; ~melodyRelease = 0.15; ~melodyCutoff = 6000;
    ~melodyAmp = 0.18;
    ~melodyNotes = [60,67,72,75, 70,67,63,67, 63,70,75,77, 72,70,63,67,
                    65,72,77,79, 75,72,65,67, 60,67,72,75, 70,67,63,60];
    ~acidAmp = 0.32;
    ~reload.value;
    90.wait;

    "[H03 4:30] climax hardLead + vcf moog...".postln;
    ~melodyInst = \hardLead;
    ~melodyAttack = 0.002; ~melodyRelease = 0.25; ~melodyCutoff = 6000;
    ~melodyAmp = 0.20;
    ~vcfOn !? { ~vcfOn.(\moog, 2500, 0.4) };
    ~reload.value;
    60.wait;

    "[H03 5:30] outro...".postln;
    ~vcfOff !? { ~vcfOff.() };
    ~melodyInst = \warmPad;
    ~melodyAttack = 0.6; ~melodyRelease = 2.5;
    ~reload.value;
    30.do { |k|
        var x = 1 - ((k + 1) / 30);
        ~kickAmp = x * 0.55; ~hatAmp = x * 0.18; ~clapAmp = x * 0.30;
        ~acidAmp = x * 0.32; ~melodyAmp = x * 0.20;
        ~reload.value; 1.wait;
    };
    [\kickSeq, \hatSeq, \snareSeq, \clapSeq, \percSeq, \acidSeq, \melodySeq, \harmonySeq].do { |k| Pdef(k).stop };
    ~fxPreset !? { ~fxPreset.(\dry) };
    "[H03 6:00] === fin 303 ASCENSION ===".postln;
}).play;
"=== TRACK H03 : 303 ASCENSION 6 min lancee ===".postln;
)
