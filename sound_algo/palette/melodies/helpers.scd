// =====================================================================
//  palette/melodies/helpers.scd
//  Helpers de generation/manipulation de patterns longs
//
//    ~stretchPattern, ~chainPatterns, ~mirror, ~sequenceUp,
//    ~callResponse, ~aabaForm, ~buildArc, ~rhythmicMotif,
//    ~melodyFromChords
//
//  Charge par palette/melodies/index.scd. Un seul bloc top-level.
// =====================================================================
(
// --- ~stretchPattern.(notes, factor) : etend un pattern court -----
// factor=2 -> chaque note tenue 2x plus longtemps (silences ajoutes)
~stretchPattern = { |notes, factor = 2|
    var out = List.new;
    notes.do { |n|
        out.add(n);
        (factor - 1).do { out.add(0) };
    };
    out.asArray;
};

// --- ~chainPatterns.([p1, p2, p3]) : enchaine plusieurs patterns ---
~chainPatterns = { |patterns|
    var out = List.new;
    patterns.do { |p| p.do { |n| out.add(n) } };
    out.asArray;
};

// --- ~mirror.(notes) : palindrome (pattern + miroir) --------------
~mirror = { |notes|
    notes ++ notes.reverse;
};

// --- ~sequenceUp.(notes, steps, transpose) : Krautrock seq style --
//   steps = nombre de repetitions, transpose = decalage par rep
~sequenceUp = { |notes, steps = 4, transpose = 2|
    var out = List.new;
    steps.do { |i|
        notes.do { |n|
            out.add(if (n > 0) { n + (transpose * i) } { 0 });
        };
    };
    out.asArray;
};

// --- ~callResponse.(call, response, n) : alterne call/response ----
~callResponse = { |call, response, n = 2|
    var out = List.new;
    n.do {
        call.do { |x| out.add(x) };
        response.do { |x| out.add(x) };
    };
    out.asArray;
};

// --- ~aabaForm.(intro, dev, climax) : structure AABA --------------
//   AABA = intro - intro - developpement - climax (defaut: dev)
~aabaForm = { |intro, dev, climax|
    var c = climax ?? { dev };
    intro ++ intro ++ dev ++ c;
};

// --- ~buildArc.(scale, len, lowOct, highOct) : arc montee/descente
~buildArc = { |scale, len = 32, lowOct = 4, highOct = 6|
    var out = List.new, half = len / 2, range = highOct - lowOct;
    half.do { |i|
        var oct = lowOct + (range * i / half);
        var deg = (i % scale.size);
        out.add(scale[deg] + (12 * oct.floor.asInteger));
    };
    half.do { |i|
        var oct = highOct - (range * i / half);
        var deg = ((scale.size - 1) - (i % scale.size)).max(0);
        out.add(scale[deg] + (12 * oct.floor.asInteger));
    };
    out.asArray;
};

// --- ~rhythmicMotif.(motif, scale, len) : motif rythmique repete --
//   motif = pattern de 0/1 (silence/note), scale = liste degres MIDI
~rhythmicMotif = { |motif, scale, len = 32|
    var out = List.new, idx = 0;
    len.do { |i|
        var hit = motif.wrapAt(i);
        if (hit > 0) {
            out.add(scale.wrapAt(idx));
            idx = idx + 1;
        } {
            out.add(0);
        };
    };
    out.asArray;
};

// --- ~melodyFromChords.(chordRoots, len, octaveRange) -------------
//   genere mel qui suit une progression d'accords
~melodyFromChords = { |chordRoots, len = 32, octRange = 1|
    var out = List.new;
    var stepsPerChord = (len / chordRoots.size).floor.asInteger;
    chordRoots.do { |r|
        stepsPerChord.do { |i|
            var pool = [r, r + 4, r + 7, r + 12, r + 11, r + 14];
            var oct = (octRange.rand2 * 12);
            if (0.7.coin) { out.add(pool.choose + oct) } { out.add(0) };
        };
    };
    out.asArray;
};

"[melodies/helpers] stretch/chain/mirror/sequenceUp/callResponse/aabaForm/buildArc/rhythmicMotif/melodyFromChords prets".postln;
)
