// =====================================================================
//  palette/note.scd  --  Source de verite : gammes + degree->note
//
//  Une seule definition de la resolution degree->note MIDI, consommee par
//  les resolveurs (~ccNote concert, ~lpNote launchpad, ~fpResolve air-piano).
//  Independant : aucun pre-requis, chargeable dans LES DEUX chemins de boot
//  (LIVE et data-only) AVANT tout consommateur.
//
//  NB : les arrays ~scaleXxx de palette/scales.scd (melodies LIVE, 8 notes
//  sur-mesure) sont distincts et NON touches ici.
//  Un seul bloc top-level (compatible .load).
// =====================================================================
(
// Gammes en OFFSETS de demi-tons depuis la fondamentale.
~scales = IdentityDictionary[
    \minor     -> [0, 2, 3, 5, 7, 8, 10],
    \dorian    -> [0, 2, 3, 5, 7, 9, 10],
    \phrygian  -> [0, 1, 3, 5, 7, 8, 10],
    \penta     -> [0, 2, 4, 7, 9],          // pentatonique majeure (concert)
    \minorPent -> [0, 3, 5, 7, 10],
    \blues     -> [0, 3, 5, 6, 7, 10],
    \japanese  -> [0, 2, 5, 7, 9],
    \hijaz     -> [0, 1, 4, 5, 7, 8, 10],
    \hirajoshi -> [0, 2, 3, 7, 8]
];

// degree -> note MIDI, avec report d'octave (mod plancher gere les degres
// negatifs : -1 descend). root en MIDI, octave en octaves entieres.
~noteFor = { |degree, scaleName = \minor, root = 60, octave = 0|
    var sc = ~scales[scaleName] ? ~scales[\minor];
    var d  = degree.asInteger;
    (root + ((octave + (d div: sc.size)) * 12) + sc[d % sc.size]).asInteger;
};

~freqFor = { |degree, scaleName = \minor, root = 60, octave = 0|
    ~noteFor.(degree, scaleName, root, octave).midicps;
};

"[OK] palette/note.scd : ~scales, ~noteFor, ~freqFor".postln;
)
