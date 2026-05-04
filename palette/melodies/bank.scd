// =====================================================================
//  palette/melodies/bank.scd
//  Bibliotheque par genre (~melodyBank) + selecteurs aleatoires.
//
//    ~melodyBank        dictionnaire genre -> [\m1, \ml3, ...]
//    ~useMelody.(\m50)  applique une melodie nommee a ~melodyNotes
//    ~melodyByGenre.(\acid)
//    ~randomLong.()     ml aleatoire   (64 pas)
//    ~randomXLong.()    mxl aleatoire  (96 pas)
//    ~randomEpic.()     mepic aleatoire(128 pas)
//
//  Le bank stocke des SYMBOLES, l'evaluation lit currentEnvironment a
//  la volee : si l'utilisateur reevalue ~m29, le selecteur utilise
//  toujours la version a jour. Charge par index.scd. Un seul bloc.
// =====================================================================
(
~melodyBank = (
    \acid:       [\m29, \m30, \m70, \ml1, \mxl5, \mepic5],
    \dub:        [\m65, \ml26],
    \trance:     [\m8, \m24, \m28, \ml2, \mxl1, \mepic1, \mxl15, \mepic6, \ml15],
    \detroit:    [\m3, \m23, \m69, \m71, \ml3, \ml18, \mxl2, \mepic3],
    \dnb:        [\m63, \ml4, \ml22],
    \ambient:    [\m33, \m34, \m72, \m73, \ml5, \mxl3],
    \world:      [\m17, \m48, \m74, \ml9, \ml25, \mxl11, \mepic9],
    \retro:      [\m61, \m75, \m77, \ml7, \ml13, \mxl6],
    \dark:       [\m14, \m38, \m53, \ml8, \ml28, \mxl8, \mepic8],
    \asian:      [\m17, \m40, \m48, \m74, \ml9, \ml25, \mxl11, \mepic9],
    \oriental:   [\m15, \m20, \m39, \m41, \m44, \m60, \ml6, \ml17, \mxl4, \mxl14, \mepic4],
    \tribal:     [\m45, \m46, \ml10, \mxl12],
    \industrial: [\m67, \m68, \ml11, \ml24, \mxl9, \mepic7],
    \synthwave:  [\m61, \ml7, \mxl6],
    \chiptune:   [\m62, \ml20, \mxl13],
    \phonk:      [\m66, \ml19],
    \hardcore:   [\m67, \ml24, \mxl9, \mepic7],
    \pop:        [\m35, \m36, \m49, \m50, \ml14, \mxl10],
    \jazz:       [\m51, \m52, \ml16, \ml27],
    \blues:      [\m16, \m47],
    \hypnotic:   [\m2, \m11, \m27, \m54, \m55, \m56, \ml12, \mxl7],
    \pad:        [\m33, \m34, \ml5, \mxl3],
    \pluck:      [\m32],
    \sub:        [\m5, \m31, \m37, \m63, \ml4],
    \drone:      [\m37, \m38],
    \tension:    [\m53, \m59, \ml28, \m58, \ml30],
    \chromatic:  [\m57, \ml29],
    \cinematic:  [\m73, \mxl3, \mepic2, \mepic10]
);

// ---------- Selecteurs ----------------------------------------------
~useMelody = { |name|
    var notes = currentEnvironment[name];
    if (notes.notNil and: { notes.isArray }) {
        ~melodyNotes = notes.copy;
        ~reload.value;
        ("useMelody : " ++ name).postln;
    } {
        ("useMelody : " ++ name ++ " inconnue").postln;
    };
};

~randomLong = {
    var key = (1..30).collect { |i| ("ml" ++ i).asSymbol }.choose;
    var notes = currentEnvironment[key];
    if (notes.notNil and: { notes.isArray }) {
        ~melodyNotes = notes.copy; ~reload.value;
        ("randomLong : " ++ key).postln;
    } { ("randomLong : " ++ key ++ " inconnue").postln };
};

~randomXLong = {
    var key = (1..15).collect { |i| ("mxl" ++ i).asSymbol }.choose;
    var notes = currentEnvironment[key];
    if (notes.notNil and: { notes.isArray }) {
        ~melodyNotes = notes.copy; ~reload.value;
        ("randomXLong : " ++ key).postln;
    } { ("randomXLong : " ++ key ++ " inconnue").postln };
};

~randomEpic = {
    var key = (1..10).collect { |i| ("mepic" ++ i).asSymbol }.choose;
    var notes = currentEnvironment[key];
    if (notes.notNil and: { notes.isArray }) {
        ~melodyNotes = notes.copy; ~reload.value;
        ("randomEpic : " ++ key).postln;
    } { ("randomEpic : " ++ key ++ " inconnue").postln };
};

~melodyByGenre = { |genre|
    var pool = ~melodyBank[genre];
    if (pool.notNil and: { pool.size > 0 }) {
        var key = pool.choose;
        var notes = currentEnvironment[key];
        if (notes.notNil and: { notes.isArray }) {
            ~melodyNotes = notes.copy; ~reload.value;
            ("melodyByGenre : " ++ genre ++ " -> " ++ key).postln;
        } { ("melodyByGenre : " ++ key ++ " inconnue (defini ?)").postln };
    } {
        ("melodyByGenre : " ++ genre ++ " inconnu ou vide").postln;
    };
};

"[melodies/bank] melodyBank + useMelody/randomLong/randomXLong/randomEpic/melodyByGenre prets".postln;
)
