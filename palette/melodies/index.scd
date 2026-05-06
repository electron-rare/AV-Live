// =====================================================================
//  palette/melodies/index.scd  --  loader recursif (post-split v2)
//
//  Charge :
//    helpers.scd                (helpers melodiques)
//    short/<*.scd>              ~m1..~m78 + ~m{Genre}100..
//    long/<*.scd>               ~ml1..~ml30 + ~ml{Genre}100..
//    xlong/<*.scd>              ~mxl1..~mxl15 + ~mxl{Genre}100..
//    epic/<*.scd>               ~mepic1..~mepic10 + ~mepic{Genre}100..
//    bank.scd                   ~melodyBank + selecteurs
//    tracks.scd                 systeme multi-pistes
//
//  Un seul bloc top-level (compatible .load).
// =====================================================================
(
var dir = thisProcess.nowExecutingPath.dirname;
(dir +/+ "helpers.scd").load;
["short", "long", "xlong", "epic"].do { |sub|
    PathName(dir +/+ sub).files.do { |f|
        if (f.extension == "scd") { f.fullPath.load };
    };
};
(dir +/+ "bank.scd").load;
(dir +/+ "tracks.scd").load;
"=== melodies module loaded (recursive) ===".postln;
)
