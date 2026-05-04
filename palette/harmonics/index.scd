// =====================================================================
//  palette/harmonics/index.scd  --  loader du module harmonics
//
//  Charge :
//    helpers.scd   genThirdHarmony / genFifthHarmony / genCounter / ...
//    presets.scd   ~enableHarmony.(\preset)  (10 presets)
//
//  Usage : (~base ++ "palette/harmonics/index.scd").load;
//  Un seul bloc top-level (compatible .load depuis 00_load.scd).
// =====================================================================
(
var dir = thisProcess.nowExecutingPath.dirname;
(dir +/+ "helpers.scd").load;
(dir +/+ "presets.scd").load;
"=== harmonics module loaded ===".postln;
)
