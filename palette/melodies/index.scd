// =====================================================================
//  palette/melodies/index.scd  --  loader du module melodies (split)
//
//  NOTE : les scales et helpers genMelody/mutate/octavate/transpose
//  /retrograde/densify/sparsify/jitter/genAcidNotes/genAcidAccents
//  /genAcidSlides/genKickPattern/randomTweak ont ete deplaces dans
//  palette/scales.scd (un cran au-dessus). 00_load.scd les charge
//  AVANT ce module via CHARGER TOUT.
//
//  Charge dans l'ordre :
//    helpers.scd      stretch/chain/mirror/sequenceUp/callResponse/...
//    short.scd        ~m1..~m78    (32 pas)
//    long.scd         ~ml1..~ml30  (64 pas)
//    xlong.scd        ~mxl1..~mxl15(96 pas)
//    epic.scd         ~mepic1..~mepic10 (128 pas)
//    bank.scd         ~melodyBank + selecteurs
//    tracks.scd       systeme multi-pistes (charge en DERNIER)
//
//  Usage : (~base ++ "palette/melodies/index.scd").load;
//  Un seul bloc top-level (compatible .load).
// =====================================================================
(
var dir = thisProcess.nowExecutingPath.dirname;
(dir +/+ "helpers.scd").load;
(dir +/+ "short.scd").load;
(dir +/+ "long.scd").load;
(dir +/+ "xlong.scd").load;
(dir +/+ "epic.scd").load;
(dir +/+ "bank.scd").load;
(dir +/+ "tracks.scd").load;
"=== melodies module loaded ===".postln;
)
