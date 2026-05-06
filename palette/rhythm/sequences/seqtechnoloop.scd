// =========================================================
//  Necessite kicks.scd STOCKAGE evalue -- extrait de sequences.scd
// =========================================================
(
~seqTechnoLoop = { |repeats = 4|
    ~seqLoop.value([
        [16, {
            ~kickSteps = ~kK1 ? [1,0,0,0, 1,0,0,0, 1,0,0,0, 1,0,0,0];
            ~reload.value; "techno A : 4/4".postln;
        }],
        [16, {
            ~kickSteps = ~kK9 ? [1,0,0,0, 1,0,0,1, 1,0,0,0, 1,0,1,0];
            ~reload.value; "techno B : ghost".postln;
        }],
        [16, {
            ~kickSteps = ~kK16 ? [1,0,0,0, 1,0,0,0, 1,0,0,1, 1,0,0,0];
            ~reload.value; "techno C : minimal".postln;
        }],
        [16, {
            ~kickSteps = ~kK10 ? [1,0,1,0, 1,0,0,1, 1,0,1,0, 1,0,1,1];
            ~reload.value; "techno D : syncope".postln;
        }],
    ], repeats);
};
"=== ~seqTechnoLoop defini ===".postln;
)
