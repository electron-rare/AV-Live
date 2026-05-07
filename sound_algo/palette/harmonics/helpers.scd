// =====================================================================
//  palette/harmonics/helpers.scd
//  Helpers de generation harmonique a partir d'une melodie source.
//
//    ~genThirdHarmony      tierce sup au-dessus
//    ~genFifthHarmony      quinte sup au-dessus
//    ~genCounterMelody     contre-melodie inversee autour d'un pivot
//    ~genArpFromChords     arpege sur progression d'accords
//    ~genBassFromMelody    bassline 2 octaves sous la melodie
//    ~genOctaveHarmony     octave sup
//    ~genSixthHarmony      sixte mineure (3 demi-tons sous l'octave)
//
//  Source unique pour ces helpers d'harmonisation (un seul bloc
//  top-level, compatible .load).
// =====================================================================
(
// --- Tierce harmonisee (3M par defaut) ------------------------------
~genThirdHarmony = { |melody, semitones = 4|
    melody.collect { |n| if (n > 0) { n + semitones } { 0 } };
};

// --- Quinte harmonisee ----------------------------------------------
~genFifthHarmony = { |melody|
    melody.collect { |n| if (n > 0) { n + 7 } { 0 } };
};

// --- Sixte mineure / harmonisation douce ----------------------------
~genSixthHarmony = { |melody|
    melody.collect { |n| if (n > 0) { n + 9 } { 0 } };
};

// --- Octave haute (layer trance) ------------------------------------
~genOctaveHarmony = { |melody, octaves = 1|
    melody.collect { |n| if (n > 0) { n + (12 * octaves) } { 0 } };
};

// --- Counter-melody (inverse autour d'un pivot) --------------------
~genCounterMelody = { |melody, rootInversion = 132|
    melody.collect { |n|
        if (n > 0) { (rootInversion - n).max(36).min(96) } { 0 };
    };
};

// --- Bassline -- 2 octaves sous la melodie --------------------------
~genBassFromMelody = { |melody, octavesDown = 2|
    melody.collect { |n|
        if (n > 0) { (n - (12 * octavesDown)).max(24) } { 0 };
    };
};

// --- Arpege sur progression d'accords -------------------------------
//   ~genArpFromChords.([root list], [chord shape], steps_par_accord, octaves)
~genArpFromChords = { |roots, shape, stepsPerChord = 8, octRange = 1|
    var notes = List.new;
    var sh = shape ?? { [0, 3, 7, 10] };  // defaut : minor 7
    roots.do { |r|
        stepsPerChord.do { |i|
            var chord = sh.collect(_ + r);
            chord = chord ++ chord.collect(_ + 12);
            if (octRange > 1) {
                chord = chord ++ chord.collect(_ + 12);
            };
            notes.add(chord.choose);
        };
    };
    notes.asArray;
};

"[harmonics/helpers] genThirdHarmony / genFifthHarmony / genSixthHarmony / genOctaveHarmony / genCounterMelody / genBassFromMelody / genArpFromChords prets".postln;
)
