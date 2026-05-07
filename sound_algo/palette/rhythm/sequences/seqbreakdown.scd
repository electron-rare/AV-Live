// =========================================================
//  ~seqBreakdown -- reduit a melody seule, puis revient -- extrait de sequences.scd
// =========================================================
(
~seqBreakdown = {
    var saveKick, saveHat, saveClap, savePerc, saveSnare;
    saveKick = ~kickSteps.copy;
    saveHat  = ~hatSteps.copy;
    saveClap = ~clapSteps.copy;
    savePerc = ~percSteps.copy;
    saveSnare = ~snareSteps.copy;
    ~seqPlay.value([
        [32, {
            ~kickSteps  = (0!16);
            ~hatSteps   = (0!16);
            ~clapSteps  = (0!16);
            ~percSteps  = (0!16);
            ~snareSteps = (0!16);
            ~reload.value;
            "breakdown : melody seule".postln;
        }],
        [16, {
            ~kickSteps  = saveKick;
            ~hatSteps   = saveHat;
            ~clapSteps  = saveClap;
            ~percSteps  = savePerc;
            ~snareSteps = saveSnare;
            ~reload.value;
            "breakdown : retour".postln;
        }],
    ]);
};
"=== ~seqBreakdown defini ===".postln;
)
