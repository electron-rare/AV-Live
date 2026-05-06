// =====================================================================
//  K12_fire_dance.scd  --  Album K "FIRE DANCE", track 12/15
//  Track autonome -- Cmd+Entree sur le bloc (...) pour la lancer.
// =====================================================================

// --- TRACK K12 : "FIRE DANCE" 5 minutes ----------------------
//   0:00 intro -> 1:00 build -> 2:15 drop -> 3:30 variation -> 4:30 outro
(
~track !? { ~track.stop };
~track = Routine({
    ~trackBegin !? { ~trackBegin.value };
    "[K12 0:00] intro -- handpan solo + perc tabla...".postln;
    ~bpm = 118;
    ~kickAmp = 0.5; ~hatAmp = 0.06; ~melodyAmp = 0.23;
    ~kickFreq = 47; ~kickPitchAmt = 3.0; ~kickDecay = 0.27;
    ~kickDrive = 1.2; ~kickClick = 0.28;
    ~melodyInst = \handpan;
    ~melodyAttack = 0.05; ~melodyRelease = 0.8; ~melodyCutoff = 3607;
    ~melodyNotes = [75,0,0,0,65,0,63,68,75,0,0,0,0,65,65,60,0,72,60,75,0,0,75,68,0,60,0,68,0,0,0,0];
    ~kickSteps = [0,1,0,0,1,1,0,0,0,0,0,0,0,0,0,0];
    ~hatSteps = [1,0,0,0,0,0,0,0,1,1,0,0,0,1,1,1];
    ~percInst = \tabla;
    ~percSteps = [0,0,0,1,1,0,0,0,1,0,0,0,1,0,0,0]; ~percAmp = 0.32;
    ~snareSteps = [0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0];
    ~clapSteps = [0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0];
    ~acidAmp = 0;
    TempoClock.default.tempo = ~bpm/60;
    ~fxPreset !? { ~fxPreset.(\dub) };
    ~reload.value;
    ~playActive !? { ~playActive.value } ?? { ~allSeqs.do { |k| Pdef(k).play } };
    ~enableHarmony.(\bassline);
    60.wait;

    "[K12 1:00] build -- kick + hat + melody plus dense...".postln;
    ~bpm = 120; TempoClock.default.tempo = ~bpm/60;
    ~kickSteps = [1,0,0,0,1,0,0,0,1,0,0,0,1,0,0,0];
    ~hatSteps = [0,0,1,0,0,0,1,0,0,0,1,0,0,0,1,0]; ~hatAmp = 0.10;
    ~melodyNotes = [75,68,0,0,58,0,0,0,58,0,58,70,72,0,70,60,68,0,68,63,0,0,0,0,67,72,0,0,0,72,0,0];
    ~melodyCutoff = 4107;
    ~percSteps = [1,1,1,1,1,0,0,1,0,1,0,0,1,0,1,1]; ~percAmp = 0.36;
    ~reload.value;
    15.do { |k|
        if (0.20.coin) { ~melodyNotes = ~mutate.(~melodyNotes, 0.2); ~reload.value };
        if (0.15.coin) { ~melodyCutoff = rrand(1448, 4607); ~reload.value };
        if (0.10.coin) { ~melodyNotes = ~octavate.(~melodyNotes, 0.2); ~reload.value };
        5.wait;
    };

    "[K12 2:15] drop -- variation + ensemble dense...".postln;
    ~bpm = 122; TempoClock.default.tempo = ~bpm/60;
    ~kickSteps = [1,0,0,0,0,0,1,0,0,0,0,0,1,0,1,0]; ~kickAmp = 0.55;
    ~clapSteps = [0,0,0,0,1,0,0,0,0,0,0,0,1,0,0,0]; ~clapAmp = 0.32;
    ~melodyNotes = [0,71,0,74,79,0,71,79,0,78,0,0,74,78,0,0,0,0,86,0,83,78,0,71,0,69,0,0,0,78,81,74];
    ~melodyAmp = 0.25;
    ~reload.value;
    12.do { |k|
        if (0.25.coin) {
            ~melodyNotes = ~genMelody.(0.5, ~scalePhrygian);
            ~reload.value;
        };
        if (0.20.coin) { ~melodyNotes = ~transpose.(~melodyNotes, [-5, -3, 3, 5, 7].choose); ~reload.value };
        if (0.15.coin) { ~percSteps = [1,1,1,1,1,0,0,1,0,1,0,0,1,0,1,1].scramble; ~reload.value };
        6.wait;
    };

    "[K12 3:30] variation -- timbre nouveau + fx evolve...".postln;
    ~bpm = 122; TempoClock.default.tempo = ~bpm/60;
    ~melodyInst = \handpan;
    ~melodyAttack = 0.01; ~melodyRelease = 0.5; ~melodyCutoff = 4407;
    ~melodyNotes = [0,0,40,49,0,0,42,0,42,49,42,0,0,0,40,45,0,42,0,37,0,0,0,0,35,37,0,0,0,37,40,49];
    ~melodyAmp = 0.23;
    ~lfoTo !? { ~lfoTo.(\melodyCutoff, 0.29, 1448, \sin, 3607) };
    ~vcfOn !? { ~vcfOn.(\moog, 1648, 0.4) };
    ~fxPreset !? { ~fxPreset.(\dub) };
    ~reload.value;
    60.wait;

    "[K12 4:30] outro -- fade global...".postln;
    ~lfoStopVar !? { ~lfoStopVar.(\melodyCutoff) };
    ~vcfOff !? { ~vcfOff.() };
    30.do { |k|
        var x = 1 - ((k + 1) / 30);
        ~melodyAmp = x * 0.23; ~kickAmp = x * 0.5;
        ~hatAmp = x * 0.10; ~percAmp = x * 0.32; ~clapAmp = x * 0.32;
        ~melodyCutoff = 250 + (x * 3607);
        ~reload.value; 1.wait;
    };
    [\kickSeq, \hatSeq, \snareSeq, \clapSeq, \percSeq, \acidSeq, \melodySeq, \harmonySeq].do { |k| Pdef(k).stop };
    ~fxPreset !? { ~fxPreset.(\dry) };
    "[K12 5:00] === fin FIRE DANCE ===".postln;
}).play;
"=== TRACK K12 : FIRE DANCE 5 min lancee ===".postln;
)
