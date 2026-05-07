// =====================================================================
//  V08_stutter_groove.scd  --  Album V "Glitch IDM", track 8/15
//  Track autonome -- Cmd+Entree sur le bloc (...) pour la lancer.
// =====================================================================

// --- TRACK V08 : "STUTTER GROOVE" 6 minutes ----------------------
//   0:00 intro -> 0:36 build -> 1:30 main -> 4:18 variations -> 5:30 outro
(
~track !? { ~track.stop };
~track = Routine({
    ~trackBegin !? { ~trackBegin.value };
    "[V08 0:00] intro stutter_groove...".postln;
    ~bpm = 128;
    ~kickFreq = 55; ~kickPitchAmt = 3.5; ~kickDecay = 0.25; ~kickClick = 0.3;
    ~kickAmp = 0; ~hatAmp = 0; ~clapAmp = 0; ~snareAmp = 0; ~percAmp = 0; ~acidAmp = 0;
    ~kickSteps = (0!16); ~hatSteps = (0!16); ~clapSteps = (0!16);
    ~snareSteps = (0!16); ~percSteps = (0!16);
    ~melodyInst = \squareLead;
    ~melodyAttack = 0.4; ~melodyRelease = 1.5; ~melodyCutoff = 2200;
    ~melodyAmp = 0.126;
    ~melodyNotes = [70,0,75,0,70,0,0,0,67,70,0,0,65,0,0,0,72,0,0,0,75,0,0,0,75,0,0,65,60,0,65,0];
    ~acidNotes = [36,36,48,36,39,36,43,39,36,41,36,39,43,36,36,41];
    ~acidSlides = [0,1,0,0,0,1,0,0,0,0,0,0,0,0,0,0];
    TempoClock.default.tempo = ~bpm/60;
    ~fxPreset !? { ~fxPreset.(\retro) };
    ~reload.value;
    ~playActive !? { ~playActive.value } ?? { ~allSeqs.do { |k| Pdef(k).play } };
    ~enableHarmony.(\counter);
    36.wait;

    "[V08 0:36] build kick + hat...".postln;
    ~kickSteps = [1,0,0,1, 0,0,1,0, 0,1,0,0, 1,0,0,0]; ~kickAmp = 0.5;
    ~hatSteps = [1,0,1,1, 0,1,1,0, 1,1,0,1, 0,1,1,0]; ~hatAmp = 0.1;
    ~clapSteps = [0,0,1,0, 1,0,0,1, 0,1,0,0, 0,0,1,0]; ~clapAmp = 0.3;
    ~melodyAmp = 0.180;
    ~reload.value;
    54.wait;

    "[V08 1:30] main groove + melody...".postln;
    ~melodyAttack = 0.01; ~melodyRelease = 0.6; ~melodyCutoff = 3500;
    ~melodyNotes = [0,60,0,60,77,67,0,67,70,0,75,72,0,70,77,0,0,0,67,0,0,65,0,65,0,60,70,70,77,0,65,0];
    ~acidAmp = 0.22;
    ~reload.value;
    168.wait;

    "[V08 4:18] variations + mutations...".postln;
    ~melodyNotes = [70,72,72,65,65,75,67,0,0,70,77,0,0,0,72,67,0,0,63,70,72,77,70,0,63,0,60,67,0,0,0,63];
    ~reload.value;
    18.do { |k|
        if (0.20.coin) {
            ~melodyNotes = ~genMelody.(0.55, [~scaleMinorPent, ~scaleMinorPent, ~scaleDorian].choose);
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

    "[V08 5:30] outro -- fade...".postln;
    30.do { |k|
        var x = 1 - ((k + 1) / 30);
        ~melodyAmp = x * 0.180;
        ~kickAmp = x * 0.5;
        ~hatAmp = x * 0.1;
        ~clapAmp = x * 0.3;
        ~acidAmp = x * 0.22;
        ~reload.value;
        1.wait;
    };
    [\kickSeq, \hatSeq, \snareSeq, \clapSeq, \percSeq, \acidSeq, \melodySeq, \harmonySeq].do { |k| Pdef(k).stop };
    ~fxPreset !? { ~fxPreset.(\dry) };
    "[V08 6:00] === fin STUTTER GROOVE ===".postln;
}).play;
"=== TRACK V08 : STUTTER GROOVE 6 min lancee ===".postln;
)
