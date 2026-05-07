// =====================================================================
//  palette/scales.scd  --  Scales + helpers de generation melodique
//
//  FUSION : ce fichier consolide les scales et helpers melodiques
//  precedemment dupliques entre engine.scd et palette/melodies/scales.scd.
//  C'est la SEULE source de verite pour les scales et les helpers.
//
//  Charge automatiquement par 00_load.scd > CHARGER TOUT, AVANT
//  palette/melodies/index.scd et palette/harmonics/index.scd.
//
//  Un seul bloc top-level (compatible .load).
// =====================================================================
(
// ---------- SCALES (toutes en C / 60 base, octaves +/-) -------------
~scaleMinor       = [60, 62, 63, 65, 67, 68, 70, 72];      // mineur naturel
~scaleDorian      = [60, 62, 63, 65, 67, 69, 70, 72];      // mineur 6e maj
~scalePhrygian    = [60, 61, 63, 65, 67, 68, 70, 72];      // sombre, 2nd min
~scaleHarmonicMin = [60, 62, 63, 65, 67, 68, 71, 72];      // 7e majeure
~scaleMinorPent   = [60, 63, 65, 67, 70, 72, 75, 79];      // pentatonique min
~scaleBlues       = [60, 63, 65, 66, 67, 70, 72, 75];      // blues
~scaleJapanese    = [60, 62, 65, 67, 69, 72, 74, 77];      // hirajoshi-like
~scaleHigh        = [72, 75, 77, 79, 82, 84, 87, 89];      // octave aigue
~scaleAcid        = [36, 36, 36, 39, 41, 43, 48, 36, 39];  // bias sub
~scaleAcidWide    = [24, 36, 36, 39, 41, 43, 48, 51];      // octave -1 a +1
~scaleAcidHigh    = [48, 48, 51, 53, 55, 60, 63];          // acid en octave +1
// Scales additionnelles (orientales / world)
~scaleHijaz       = [60, 61, 64, 65, 67, 68, 70, 72];      // arabe (b2, 3M)
~scaleHirajoshi   = [60, 62, 63, 67, 68, 72, 74, 75];      // pent jap sombre
~scaleVietnam     = [60, 63, 65, 67, 70, 72, 75, 77];      // pent vietnam min
~scaleVietnamMaj  = [60, 62, 64, 67, 69, 72, 74, 76];      // pent vietnam maj
~scaleHungarian   = [60, 62, 63, 66, 67, 68, 71, 72];      // gypsy mineur

// ---------- HELPERS DE GENERATION MELODIQUE -------------------------

// Genere une melodie de longueur `len` avec densite donnee
// (0=tout vide, 1=plein). len defaut 32 pas.
~genMelody = { |density = 0.55, scale, len = 32|
    var s = scale ?? { ~scaleMinorPent };
    len.collect { if (density.coin) { s.choose } { 0 } };
};

// Mutate : remplace une fraction des notes (proba) par d'autres de la scale
~mutate = { |notes, proba = 0.2, scale|
    var s = scale ?? { ~scaleMinorPent };
    notes.collect { |n|
        if (n > 0 and: { proba.coin }) { s.choose } { n }
    };
};

// Octavate : decale aleatoirement chaque note de +/- 1 octave (proba)
~octavate = { |notes, proba = 0.3|
    notes.collect { |n|
        if (n > 0 and: { proba.coin }) {
            n + ([-12, 12, 12].choose);
        } { n };
    };
};

// Transpose : decale toutes les notes (sauf 0) de N demi-tons
~transpose = { |notes, semitones|
    notes.collect { |n| if (n > 0) { n + semitones } { 0 } };
};

// Retrograde : inverse l'ordre des notes
~retrograde = { |notes| notes.reverse };

// Density : ajoute des notes aleatoires dans les silences (proba)
~densify = { |notes, proba = 0.3, scale|
    var s = scale ?? { ~scaleMinorPent };
    notes.collect { |n|
        if (n == 0 and: { proba.coin }) { s.choose } { n }
    };
};

// Sparsify : enleve aleatoirement des notes (proba)
~sparsify = { |notes, proba = 0.3|
    notes.collect { |n| if (proba.coin) { 0 } { n } };
};

// Jitter : multiplie une valeur par un facteur aleatoire (+/- amount)
~jitter = { |val, amount = 0.1| val * rrand(1.0 - amount, 1.0 + amount) };

// Genere 16 notes acid en piochant dans la scale (avec biais sub)
~genAcidNotes   = { |scale| 16.collect { (scale ?? { ~scaleAcid }).choose } };
~genAcidAccents = { |density = 0.4|  16.collect { if (density.coin) {1} {0} } };
~genAcidSlides  = { |density = 0.25, len = 16|
    len.collect { if (density.coin) {1} {0} };
};

// Genere un pattern kick avec ghost notes (probabilite par step)
~genKickPattern = { |density = 0.3|
    // garde les 4 temps forts, ajoute des ghosts aleatoires
    16.collect { |i|
        if (i.mod(4) == 0) { 1 } { if (density.coin) { 1 } { 0 } };
    };
};

// Randomize : appelle dans une track pour micro-variations
//  proba : chance d'appliquer un changement (0.0 a 1.0)
~randomTweak = { |proba = 0.3|
    if (proba.coin) { ~acidCutoff = rrand(400, 1800) };
    if (proba.coin) { ~acidRq = rrand(0.08, 0.25) };
    if (proba.coin) { ~melodyCutoff = rrand(1500, 3500) };
    if ((proba * 0.5).coin) { ~kickClick = rrand(0.05, 0.4) };
    ~reload.value;
};

"=== scales + helpers melodiques charges ===".postln;
)
