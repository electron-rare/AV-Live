// =====================================================================
//  G13_paradise_garage.scd  --  Album G, track 13/15
// =====================================================================

// --- TRACK G13 : "PARADISE GARAGE" 4 minutes -------------------------
//   0:00 organ + kick -> 1:30 lead -> 3:30 outro
(
~track !? { ~track.stop };
~track = Routine({
    ~trackBegin !? { ~trackBegin.value };
    "[G13 0:00] organ + kick paradise...".postln;
    ~bpm = 125;
    ~kickSteps = [1,0,0,0, 1,0,0,0, 1,0,0,0, 1,0,0,0]; ~kickAmp = 0.50;
    ~kickFreq = 50; ~kickPitchAmt = 3.0; ~kickDecay = 0.32; ~kickClick = 0.15;
    ~hatSteps = [0,0,1,0, 0,0,1,0, 0,0,1,0, 0,0,1,0]; ~hatAmp = 0.16;
    ~clapSteps = [0,0,0,0, 1,0,0,0, 0,0,0,0, 1,0,0,0]; ~clapAmp = 0.32;
    ~snareSteps=(0!16); ~percSteps=(0!16); ~acidAmp=0;
    ~melodyInst = \organLead;
    ~melodyAttack = 0.005; ~melodyRelease = 0.18; ~melodyCutoff = 4500;
    ~melodyAmp = 0.20;
    ~melodyNotes = [63,0,67,0, 70,0,72,0, 70,0,67,0, 63,0,60,0,
                    65,0,67,0, 72,0,75,0, 72,0,70,0, 67,0,65,0];
    TempoClock.default.tempo = ~bpm/60;
    ~fxPreset !? { ~fxPreset.(\dub) };
    ~reload.value;
    ~playActive !? { ~playActive.value } ?? { ~allSeqs.do { |k| Pdef(k).play } };
    ~enableHarmony.(\chord);
    90.wait;

    "[G13 1:30] hardLead disco...".postln;
    ~melodyInst = \hardLead;
    ~melodyAttack = 0.005; ~melodyRelease = 0.25; ~melodyCutoff = 5000;
    ~melodyAmp = 0.18;
    ~melodyNotes = ~genMelody.(0.55, ~scaleMinorPent);
    ~reload.value;
    24.do { |k|
        if (0.20.coin) {
            ~melodyNotes = ~genMelody.(0.55, ~scaleMinorPent);
            ~reload.value;
        };
        5.wait;
    };

    "[G13 3:30] outro...".postln;
    ~melodyInst = \warmPad;
    ~melodyAttack = 0.5; ~melodyRelease = 1.8;
    ~reload.value;
    30.do { |k|
        var x = 1 - ((k + 1) / 30);
        ~kickAmp = x * 0.50; ~hatAmp = x * 0.16; ~clapAmp = x * 0.32;
        ~melodyAmp = x * 0.20;
        ~reload.value; 1.wait;
    };
    [\kickSeq, \hatSeq, \snareSeq, \clapSeq, \percSeq, \acidSeq, \melodySeq, \harmonySeq].do { |k| Pdef(k).stop };
    ~fxPreset !? { ~fxPreset.(\dry) };
    "[G13 4:00] === fin PARADISE GARAGE ===".postln;
}).play;
"=== TRACK G13 : PARADISE GARAGE 4 min lancee ===".postln;
)
