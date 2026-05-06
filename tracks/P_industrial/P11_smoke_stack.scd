// =====================================================================
//  P11_smoke_stack.scd  --  Album P "Industrial", track 11/15
//  Track autonome -- Cmd+Entree sur le bloc (...) pour la lancer.
//  Sub-track : "Smoke Stack" 7 min (420s)
// =====================================================================

// --- TRACK P11 : "SMOKE STACK" 7 minutes -------------
//   0:00 intro -> 1:37 groove -> 3:34 drop -> 5:11 variations -> 6:30 outro
(
~track !? { ~track.stop };
~track = Routine({
    ~trackBegin !? { ~trackBegin.value };
    "[P11 0:00] intro / atmosphere...".postln;
    ~bpm = 142;
    ~kickFreq = 60; ~kickPitchAmt = 5.0; ~kickDecay = 0.28;
    ~kickDrive = 3.5; ~kickClick = 0.3;
    ~kickSteps = [1,0,0,0, 1,0,0,0, 1,0,0,0, 1,0,0,0]; ~kickAmp = 0.55;
    ~hatSteps  = [0,1,0,1, 1,1,0,1, 0,1,0,1, 1,1,0,1]; ~hatAmp = 0.1;
    ~snareSteps = [0,0,0,0, 1,0,0,0, 0,0,0,0, 1,0,1,0]; ~snareAmp = 0.45;
    ~clapSteps = [0,0,0,0, 1,0,0,0, 0,0,0,0, 1,0,0,1]; ~clapAmp = 0.4;
    ~percInst = \tom;
    ~percSteps = [0,0,1,0, 0,0,1,0, 0,0,1,0, 0,0,1,0]; ~percAmp = 0.30;
    ~melodyInst = \hooverbass;
    ~melodyAttack = 0.01; ~melodyRelease = 0.3; ~melodyCutoff = 1200;
    ~melodyAmp = 0.144;
    ~melodyNotes = ~genMelody.(0.45, ~scalePhrygian);
    ~acidNotes = [36,0,48,0,36,0,43,0, 36,0,41,0,39,0,36,0];
    ~acidSlides = [0,0,1,0,0,0,0,1, 0,0,0,1,0,0,0,0];
    ~acidCutoff = 800; ~acidRq = 0.18; ~acidDrive = 2.5; ~acidAmp = 0.120;
    TempoClock.default.tempo = ~bpm/60;
    ~fxPreset !? { ~fxPreset.(\industrial) };
    ~reload.value;
    ~playActive !? { ~playActive.value } ?? { ~allSeqs.do { |k| Pdef(k).play } };
    ~enableHarmony.(\bassline);
    97.wait;

    "[P11 1:37] build / groove...".postln;
    ~melodyAmp = 0.204;
    ~melodyNotes = ~genMelody.(0.55, ~scaleHarmonicMin);
    ~melodyCutoff = 1800;
    ~reload.value;
    29.do { |k|
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

    "[P11 3:34] drop / climax...".postln;
    ~melodyAmp = 0.240;
    ~kickAmp = 0.600;
    ~melodyNotes = ~genMelody.(0.6, ~scaleMinor);
    ~melodyCutoff = 2400;
    ~acidAmp = 0.200;
    ~acidCutoff = 1500; ~acidDrive = 3.2;
    ~reload.value;
    19.do { |k|
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

    "[P11 5:11] variations / second wave...".postln;
    ~melodyInst = \fmBass;
    ~melodyAttack = 0.01; ~melodyRelease = 0.4;
    ~melodyAmp = 0.216;
    ~melodyNotes = ~genMelody.(0.5, ~scalePhrygian);
    ~melodyCutoff = 2000;
    ~vcfOn !? { ~vcfOn.(\moog, 1600, 0.5) };
    ~reload.value;
    79.wait;

    "[P11 6:30] outro -- fade...".postln;
    ~vcfOff !? { ~vcfOff.() };
    30.do { |k|
        var x = 1 - ((k + 1) / 30);
        ~melodyAmp = x * 0.240;
        ~kickAmp = x * 0.550;
        ~hatAmp = x * 0.100;
        ~snareAmp = x * 0.450;
        ~clapAmp = x * 0.400;
        ~acidAmp = x * 0.200;
        ~reload.value; 1.wait;
    };
    [\kickSeq, \hatSeq, \snareSeq, \clapSeq, \percSeq, \acidSeq, \melodySeq, \harmonySeq]
        .do { |k| Pdef(k).stop };
    ~fxPreset !? { ~fxPreset.(\dry) };
    "[P11 7:00] === fin SMOKE STACK ===".postln;
}).play;
"=== TRACK P11 : SMOKE STACK 7 min lancee ===".postln;
)
