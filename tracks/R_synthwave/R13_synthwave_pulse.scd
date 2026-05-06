// =====================================================================
//  R13_synthwave_pulse.scd  --  Album R "Synthwave", track 13/15
//  Track autonome -- Cmd+Entree sur le bloc (...) pour la lancer.
//  Sub-track : "Synthwave Pulse" 4 min (240s)
// =====================================================================

// --- TRACK R13 : "SYNTHWAVE PULSE" 4 minutes -------------
//   0:00 intro -> 0:52 groove -> 1:55 drop -> 2:47 variations -> 3:30 outro
(
~track !? { ~track.stop };
~track = Routine({
    ~trackBegin !? { ~trackBegin.value };
    "[R13 0:00] intro / atmosphere...".postln;
    ~bpm = 111;
    ~kickFreq = 55; ~kickPitchAmt = 3.0; ~kickDecay = 0.32;
    ~kickDrive = 1.0; ~kickClick = 0.18;
    ~kickSteps = [1,0,0,0, 1,0,0,0, 1,0,0,0, 1,0,0,0]; ~kickAmp = 0.5;
    ~hatSteps  = [0,0,1,0, 0,0,1,0, 0,0,1,0, 0,0,1,0]; ~hatAmp = 0.13;
    ~snareSteps = [0,0,0,0, 1,0,0,0, 0,0,0,0, 1,0,0,0]; ~snareAmp = 0.4;
    ~clapSteps = [0,0,0,0, 1,0,0,0, 0,0,0,0, 1,0,0,0]; ~clapAmp = 0.3;
    ~percInst = \tom;
    ~percSteps = [0,0,1,0, 0,0,1,0, 0,0,1,0, 0,0,1,0]; ~percAmp = 0.30;
    ~melodyInst = \saw3;
    ~melodyAttack = 0.005; ~melodyRelease = 0.4; ~melodyCutoff = 3000;
    ~melodyAmp = 0.108;
    ~melodyNotes = ~genMelody.(0.45, ~scaleDorian);
    ~acidNotes = [36,0,48,0,36,0,43,0, 36,0,41,0,39,0,36,0];
    ~acidSlides = [0,0,1,0,0,0,0,1, 0,0,0,1,0,0,0,0];
    ~acidCutoff = 800; ~acidRq = 0.18; ~acidDrive = 2.5; ~acidAmp = 0.000;
    TempoClock.default.tempo = ~bpm/60;
    ~fxPreset !? { ~fxPreset.(\retro) };
    ~reload.value;
    ~playActive !? { ~playActive.value } ?? { ~allSeqs.do { |k| Pdef(k).play } };
    ~enableHarmony.(\chord);
    52.wait;

    "[R13 0:52] build / groove...".postln;
    ~melodyAmp = 0.153;
    ~melodyNotes = ~genMelody.(0.55, ~scaleMinor);
    ~melodyCutoff = 3600;
    ~reload.value;
    15.do { |k|
        if (0.20.coin) {
            ~melodyNotes = ~mutate.(~melodyNotes, 0.25);
            ~reload.value;
        };
        if (0.15.coin) {
            ~acidCutoff = rrand(500, 1800); ~reload.value;
        };
        if (0.10.coin) {
            ~melodyNotes = ~octavate.(~melodyNotes, 0.3); ~reload.value;
        };
        4.wait;
    };

    "[R13 1:55] drop / climax...".postln;
    ~melodyAmp = 0.180;
    ~kickAmp = 0.550;
    ~melodyNotes = ~genMelody.(0.6, ~scaleMinorPent);
    ~melodyCutoff = 4200;
    ~acidAmp = 0.000;
    ~acidCutoff = 1500; ~acidDrive = 3.2;
    ~reload.value;
    10.do { |k|
        if (0.20.coin) {
            ~melodyNotes = ~mutate.(~melodyNotes, 0.2);
            ~reload.value;
        };
        if (0.10.coin) {
            ~melodyNotes = ~transpose.(~melodyNotes, [-5, -3, 3, 5, 7].choose);
            ~reload.value;
        };
        5.wait;
    };

    "[R13 2:47] variations / second wave...".postln;
    ~melodyInst = \squareLead;
    ~melodyAttack = 0.005; ~melodyRelease = 0.5;
    ~melodyAmp = 0.162;
    ~melodyNotes = ~genMelody.(0.5, ~scaleMinor);
    ~melodyCutoff = 3800;
    ~vcfOn !? { ~vcfOn.(\moog, 3400, 0.5) };
    ~reload.value;
    43.wait;

    "[R13 3:30] outro -- fade...".postln;
    ~vcfOff !? { ~vcfOff.() };
    30.do { |k|
        var x = 1 - ((k + 1) / 30);
        ~melodyAmp = x * 0.180;
        ~kickAmp = x * 0.500;
        ~hatAmp = x * 0.130;
        ~snareAmp = x * 0.400;
        ~clapAmp = x * 0.300;
        ~acidAmp = x * 0.000;
        ~reload.value; 1.wait;
    };
    [\kickSeq, \hatSeq, \snareSeq, \clapSeq, \percSeq, \acidSeq, \melodySeq, \harmonySeq]
        .do { |k| Pdef(k).stop };
    ~fxPreset !? { ~fxPreset.(\dry) };
    "[R13 4:00] === fin SYNTHWAVE PULSE ===".postln;
}).play;
"=== TRACK R13 : SYNTHWAVE PULSE 4 min lancee ===".postln;
)
