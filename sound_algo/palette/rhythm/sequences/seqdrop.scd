// =========================================================
//  ~seqDrop -- 4 steps silence + 1 step impact + reprise -- extrait de sequences.scd
// =========================================================
(
~seqDrop = {
    var saveKick, saveHat, saveClap, savePerc, saveSnare;
    saveKick = ~kickSteps.copy;
    saveHat  = ~hatSteps.copy;
    saveClap = ~clapSteps.copy;
    savePerc = ~percSteps.copy;
    saveSnare = ~snareSteps.copy;
    ~seqPlay.value([
        [4, {
            ~kickSteps  = (0!16);
            ~hatSteps   = (0!16);
            ~clapSteps  = (0!16);
            ~percSteps  = (0!16);
            ~snareSteps = (0!16);
            ~reload.value;
            "drop : SILENCE".postln;
        }],
        [1, {
            // impact one-shot via clap fort
            ~clapSteps = [1,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0];
            ~clapAmp = 0.7;
            ~reload.value;
            "drop : IMPACT".postln;
        }],
        [16, {
            ~kickSteps  = saveKick;
            ~hatSteps   = saveHat;
            ~clapSteps  = saveClap;  ~clapAmp = 0.35;
            ~percSteps  = savePerc;
            ~snareSteps = saveSnare;
            ~reload.value;
            "drop : DROP !!!".postln;
        }],
    ]);
};
"=== ~seqDrop defini ===".postln;
)
