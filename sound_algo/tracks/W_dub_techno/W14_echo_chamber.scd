// =====================================================================
//  W14_echo_chamber.scd  --  Album W "Dub Techno", track 14/15
//  Track autonome -- Cmd+Entree sur le bloc (...) pour la lancer.
// =====================================================================

// --- TRACK W14 : "ECHO CHAMBER" 5 minutes ----------------------
//   0:00 intro -> 0:30 build -> 1:15 main -> 3:30 variations -> 4:30 outro
(
~track !? { ~track.stop };
~track = Routine({
    ~trackBegin !? { ~trackBegin.value };
    "[W14 0:00] intro echo_chamber...".postln;
    ~bpm = 124;
    ~kickFreq = 48; ~kickPitchAmt = 2.5; ~kickDecay = 0.45; ~kickClick = 0.08;
    ~kickAmp = 0; ~hatAmp = 0; ~clapAmp = 0; ~snareAmp = 0; ~percAmp = 0; ~acidAmp = 0;
    ~kickSteps = (0!16); ~hatSteps = (0!16); ~clapSteps = (0!16);
    ~snareSteps = (0!16); ~percSteps = (0!16);
    ~melodyInst = \rhodes;
    ~melodyAttack = 0.4; ~melodyRelease = 1.5; ~melodyCutoff = 2200;
    ~melodyAmp = 0.126;
    ~melodyNotes = [72,0,0,0,65,0,0,0,65,0,0,0,63,0,0,68,65,0,0,70,70,60,0,65,72,70,0,0,70,0,0,0];
    ~acidNotes = [36,36,48,36,39,36,43,39,36,41,36,39,43,36,36,41];
    ~acidSlides = [0,0,1,0,0,0,0,0,0,0,1,0,0,0,1,0];
    TempoClock.default.tempo = ~bpm/60;
    ~fxPreset !? { ~fxPreset.(\dub) };
    ~reload.value;
    ~playActive !? { ~playActive.value } ?? { ~allSeqs.do { |k| Pdef(k).play } };
    ~enableHarmony.(\arp);
    30.wait;

    "[W14 0:30] build kick + hat...".postln;
    ~kickSteps = [1,0,0,0, 1,0,0,0, 1,0,0,0, 1,0,0,0]; ~kickAmp = 0.45;
    ~hatSteps = [0,0,1,0, 0,0,1,0, 0,0,1,0, 0,0,1,0]; ~hatAmp = 0.06;
    ~clapSteps = [0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0]; ~clapAmp = 0.0;
    ~melodyAmp = 0.180;
    ~reload.value;
    45.wait;

    "[W14 1:15] main groove + melody...".postln;
    ~melodyAttack = 0.01; ~melodyRelease = 0.6; ~melodyCutoff = 3500;
    ~melodyNotes = [0,0,0,0,63,63,72,62,0,60,0,0,62,70,68,60,62,68,72,63,70,67,0,72,68,60,67,68,0,63,0,72];
    ~acidAmp = 0.22;
    ~reload.value;
    135.wait;

    "[W14 3:30] variations + mutations...".postln;
    ~melodyNotes = [0,0,68,70,70,60,0,0,0,63,0,67,62,62,60,0,72,60,63,0,65,72,68,60,60,63,68,62,62,67,67,0];
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

    "[W14 4:30] outro -- fade...".postln;
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
    "[W14 5:00] === fin ECHO CHAMBER ===".postln;
}).play;
"=== TRACK W14 : ECHO CHAMBER 5 min lancee ===".postln;
)
