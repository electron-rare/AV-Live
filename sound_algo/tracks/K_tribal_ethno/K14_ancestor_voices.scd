// =====================================================================
//  K14_ancestor_voices.scd  --  Album K "ANCESTOR VOICES", track 14/15
//  Track autonome -- Cmd+Entree sur le bloc (...) pour la lancer.
// =====================================================================

// --- TRACK K14 : "ANCESTOR VOICES" 5 minutes ----------------------
//   0:00 intro -> 1:00 build -> 2:15 drop -> 3:30 variation -> 4:30 outro
(
~track !? { ~track.stop };
~track = Routine({
    ~trackBegin !? { ~trackBegin.value };
    "[K14 0:00] intro -- choir solo + perc tom...".postln;
    ~bpm = 105;
    ~kickAmp = 0.49; ~hatAmp = 0.06; ~melodyAmp = 0.23;
    ~kickFreq = 59; ~kickPitchAmt = 3.8; ~kickDecay = 0.48;
    ~kickDrive = 1.2; ~kickClick = 0.14;
    ~melodyInst = \choir;
    ~melodyAttack = 0.05; ~melodyRelease = 0.8; ~melodyCutoff = 3232;
    ~melodyNotes = [67,0,72,0,0,0,0,0,62,0,77,70,0,65,0,74,0,0,0,0,0,0,0,67,0,67,0,0,0,0,65,67];
    ~kickSteps = [1,0,1,0,0,0,0,0,0,0,0,0,0,0,0,0];
    ~hatSteps = [0,0,0,0,0,0,1,0,1,0,0,0,0,0,1,0];
    ~percInst = \tom;
    ~percSteps = [0,0,0,0,1,1,1,0,1,0,1,1,0,1,0,0]; ~percAmp = 0.32;
    ~snareSteps = [0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0];
    ~clapSteps = [0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0];
    ~acidAmp = 0;
    TempoClock.default.tempo = ~bpm/60;
    ~fxPreset !? { ~fxPreset.(\space) };
    ~reload.value;
    ~playActive !? { ~playActive.value } ?? { ~allSeqs.do { |k| Pdef(k).play } };
    ~enableHarmony.(\cinematic);
    60.wait;

    "[K14 1:00] build -- kick + hat + melody plus dense...".postln;
    ~bpm = 103; TempoClock.default.tempo = ~bpm/60;
    ~kickSteps = [1,0,0,0,1,0,0,0,1,0,0,0,1,0,0,0];
    ~hatSteps = [0,0,1,0,0,0,1,0,0,0,1,0,0,0,1,0]; ~hatAmp = 0.10;
    ~melodyNotes = [0,69,67,67,67,70,0,0,0,77,65,70,0,70,67,0,0,0,67,0,67,0,0,72,65,69,0,0,74,67,65,69];
    ~melodyCutoff = 3732;
    ~percSteps = [1,0,1,0,1,0,1,0,0,1,0,0,0,0,0,1]; ~percAmp = 0.36;
    ~reload.value;
    15.do { |k|
        if (0.20.coin) { ~melodyNotes = ~mutate.(~melodyNotes, 0.2); ~reload.value };
        if (0.15.coin) { ~melodyCutoff = rrand(1229, 4232); ~reload.value };
        if (0.10.coin) { ~melodyNotes = ~octavate.(~melodyNotes, 0.2); ~reload.value };
        5.wait;
    };

    "[K14 2:15] drop -- variation + ensemble dense...".postln;
    ~bpm = 101; TempoClock.default.tempo = ~bpm/60;
    ~kickSteps = [1,0,0,0,0,0,1,0,0,0,0,0,1,0,1,0]; ~kickAmp = 0.54;
    ~clapSteps = [0,0,0,0,1,0,0,0,0,0,0,0,1,0,0,0]; ~clapAmp = 0.32;
    ~melodyNotes = [0,88,0,0,81,88,91,76,91,0,0,83,79,0,0,76,0,0,91,0,0,0,0,0,0,0,0,0,81,88,74,0];
    ~melodyAmp = 0.25;
    ~reload.value;
    12.do { |k|
        if (0.25.coin) {
            ~melodyNotes = ~genMelody.(0.5, ~scaleHarmonicMin);
            ~reload.value;
        };
        if (0.20.coin) { ~melodyNotes = ~transpose.(~melodyNotes, [-5, -3, 3, 5, 7].choose); ~reload.value };
        if (0.15.coin) { ~percSteps = [1,0,1,0,1,0,1,0,0,1,0,0,0,0,0,1].scramble; ~reload.value };
        6.wait;
    };

    "[K14 3:30] variation -- timbre nouveau + fx evolve...".postln;
    ~bpm = 109; TempoClock.default.tempo = ~bpm/60;
    ~melodyInst = \choir;
    ~melodyAttack = 0.01; ~melodyRelease = 0.5; ~melodyCutoff = 4032;
    ~melodyNotes = [0,0,0,0,38,0,0,0,0,0,0,0,38,0,0,47,0,0,0,40,52,0,48,0,48,40,0,0,0,0,40,0];
    ~melodyAmp = 0.23;
    ~lfoTo !? { ~lfoTo.(\melodyCutoff, 0.34, 1229, \sin, 3232) };
    ~vcfOn !? { ~vcfOn.(\moog, 1429, 0.4) };
    ~fxPreset !? { ~fxPreset.(\space) };
    ~reload.value;
    60.wait;

    "[K14 4:30] outro -- fade global...".postln;
    ~lfoStopVar !? { ~lfoStopVar.(\melodyCutoff) };
    ~vcfOff !? { ~vcfOff.() };
    30.do { |k|
        var x = 1 - ((k + 1) / 30);
        ~melodyAmp = x * 0.23; ~kickAmp = x * 0.49;
        ~hatAmp = x * 0.10; ~percAmp = x * 0.32; ~clapAmp = x * 0.32;
        ~melodyCutoff = 250 + (x * 3232);
        ~reload.value; 1.wait;
    };
    [\kickSeq, \hatSeq, \snareSeq, \clapSeq, \percSeq, \acidSeq, \melodySeq, \harmonySeq].do { |k| Pdef(k).stop };
    ~fxPreset !? { ~fxPreset.(\dry) };
    "[K14 5:00] === fin ANCESTOR VOICES ===".postln;
}).play;
"=== TRACK K14 : ANCESTOR VOICES 5 min lancee ===".postln;
)
