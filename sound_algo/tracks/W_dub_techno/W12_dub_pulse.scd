// =====================================================================
//  W12_dub_pulse.scd  --  Album W "Dub Techno", track 12/15
//  Track autonome -- Cmd+Entree sur le bloc (...) pour la lancer.
// =====================================================================

// --- TRACK W12 : "DUB PULSE" 5 minutes ----------------------
//   0:00 intro -> 0:30 build -> 1:15 main -> 3:30 variations -> 4:30 outro
(
~track !? { ~track.stop };
~track = Routine({
    ~trackBegin !? { ~trackBegin.value };
    "[W12 0:00] intro dub_pulse...".postln;
    ~bpm = 122;
    ~kickFreq = 48; ~kickPitchAmt = 2.5; ~kickDecay = 0.45; ~kickClick = 0.08;
    ~kickAmp = 0; ~hatAmp = 0; ~clapAmp = 0; ~snareAmp = 0; ~percAmp = 0; ~acidAmp = 0;
    ~kickSteps = (0!16); ~hatSteps = (0!16); ~clapSteps = (0!16);
    ~snareSteps = (0!16); ~percSteps = (0!16);
    ~melodyInst = \stab;
    ~melodyAttack = 0.4; ~melodyRelease = 1.5; ~melodyCutoff = 2200;
    ~melodyAmp = 0.126;
    ~melodyNotes = [72,0,0,0,70,70,0,0,70,0,68,0,65,0,0,0,62,0,0,0,72,0,0,0,67,0,0,0,60,0,0,0];
    ~acidNotes = [36,36,48,36,39,36,43,39,36,41,36,39,43,36,36,41];
    ~acidSlides = [1,0,1,0,0,0,1,0,0,1,1,0,1,0,0,0];
    TempoClock.default.tempo = ~bpm/60;
    ~fxPreset !? { ~fxPreset.(\dub) };
    ~reload.value;
    ~playActive !? { ~playActive.value } ?? { ~allSeqs.do { |k| Pdef(k).play } };
    ~enableHarmony.(\bassline);
    30.wait;

    "[W12 0:30] build kick + hat...".postln;
    ~kickSteps = [1,0,0,0, 1,0,0,0, 1,0,0,0, 1,0,0,0]; ~kickAmp = 0.45;
    ~hatSteps = [0,0,1,0, 0,0,1,0, 0,0,1,0, 0,0,1,0]; ~hatAmp = 0.06;
    ~clapSteps = [0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0]; ~clapAmp = 0.0;
    ~melodyAmp = 0.180;
    ~reload.value;
    45.wait;

    "[W12 1:15] main groove + melody...".postln;
    ~melodyAttack = 0.01; ~melodyRelease = 0.6; ~melodyCutoff = 3500;
    ~melodyNotes = [70,67,62,0,72,63,0,70,0,72,0,67,63,62,0,62,60,62,72,70,0,0,72,68,0,0,0,0,63,62,0,0];
    ~acidAmp = 0.22;
    ~reload.value;
    135.wait;

    "[W12 3:30] variations + mutations...".postln;
    ~melodyNotes = [60,63,70,0,0,62,72,70,63,0,0,72,72,65,70,60,70,0,0,0,67,70,72,60,70,62,70,0,68,70,67,0];
    ~reload.value;
    15.do { |k|
        if (0.20.coin) {
            ~melodyNotes = ~genMelody.(0.55, [~scaleMinor, ~scaleMinorPent, ~scaleDorian].choose);
        };
        if (0.20.coin) {
            ~melodyNotes = ~mutate.(~melodyNotes, 0.2);
        };
        if (0.15.coin) {
            ~melodyCutoff = rrand(1500, 5500);
        };
        if (0.10.coin) {
            ~melodyNotes = ~octavate.(~melodyNotes, 0.25);
        };
        ~reload.value;
        4.wait;
    };

    "[W12 4:30] outro -- fade...".postln;
    30.do { |k|
        var x = 1 - ((k + 1) / 30);
        ~melodyAmp = x * 0.180;
        ~kickAmp = x * 0.45;
        ~hatAmp = x * 0.06;
        ~clapAmp = x * 0.0;
        ~acidAmp = x * 0.22;
        ~reload.value;
        1.wait;
    };
    [\kickSeq, \hatSeq, \snareSeq, \clapSeq, \percSeq, \acidSeq, \melodySeq, \harmonySeq].do { |k| Pdef(k).stop };
    ~fxPreset !? { ~fxPreset.(\dry) };
    "[W12 5:00] === fin DUB PULSE ===".postln;
}).play;
"=== TRACK W12 : DUB PULSE 5 min lancee ===".postln;
)
