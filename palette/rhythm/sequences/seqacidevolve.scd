// =========================================================
//  Note: lit ~acidNotes / ~acidAccents / ~acidSlides du moteur -- extrait de sequences.scd
// =========================================================
(
~seqAcidEvolve = {
    ~seqPlay.value([
        [16, {
            ~acidNotes = [36,36,36,36, 36,36,36,36, 36,36,36,36, 36,36,36,36];
            ~acidAccents = [1,0,0,0, 1,0,0,0, 1,0,0,0, 1,0,0,0];
            ~acidSlides  = [0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0];
            ~reload.value; "acid 1: drone tonic".postln;
        }],
        [16, {
            ~acidNotes = [36,0,39,0, 36,0,43,0, 36,0,39,0, 36,0,43,0];
            ~acidAccents = [1,0,0,0, 1,0,1,0, 1,0,0,0, 1,0,1,0];
            ~reload.value; "acid 2: minor 3rd".postln;
        }],
        [16, {
            ~acidNotes = [36,39,43,36, 39,43,48,43, 36,39,43,48, 43,39,36,43];
            ~acidAccents = [1,0,0,1, 0,1,0,0, 1,0,0,1, 0,0,1,0];
            ~acidSlides  = [0,1,0,0, 1,0,1,0, 0,0,1,0, 1,1,0,0];
            ~reload.value; "acid 3: arpege".postln;
        }],
        [16, {
            ~acidNotes = [36,43,39,48, 36,46,43,48, 39,43,48,46, 43,39,48,36];
            ~acidAccents = [1,0,1,1, 0,1,0,1, 1,0,1,0, 0,1,1,0];
            ~acidSlides  = [1,1,0,1, 0,0,1,1, 0,1,0,1, 1,0,1,0];
            ~reload.value; "acid 4: full chaos".postln;
        }],
    ]);
};
"=== ~seqAcidEvolve defini ===".postln;
)
