// Headless validator: load all generated .matrix presets via the engine.
// Run: /Applications/SuperCollider.app/Contents/MacOS/sclang \
//        sound_algo/data_only/matrix_presets/validate_presets.scd
// Expected output: VALIDATE PASS  (no ERROR lines, 28 presets loaded OK)
// Also asserts techno_drive carries non-empty voiceMods + voicePoses.
(
var featureFile = PathName(thisProcess.nowExecutingPath).pathOnly ++ "../matrix.scd";
var pass  = true;
var nOK   = 0;
var nFail = 0;
var names;

// Minimal stub environment (mirrors test_matrix.scd setup)
~lp       = (clock: TempoClock.default);
~toscSend  = { |path ...args| };
~toscTouch = { |addr| };

// Dummy Pdefs so matrix.scd initialises without missing references
["kick","hats","clap","perc","sub","acid","arp","lead",
 "stab","pad","ride","rim","tom","reese","bells","sweep",
 "melody","chord","fx","snare","crash","shaker"].do { |v|
    Pdef(("lp_" ++ v).asSymbol, Pbind(\instrument, v.asSymbol, \dur, 1))
};

featureFile.load;

// -- 1. Load every preset, assert each returns true --
names = ~matNames.(~matPresetDir);
("found " ++ names.size ++ " presets in " ++ ~matPresetDir).postln;

names.do { |name|
    var path = ~matPresetDir +/+ (name.asString ++ ".matrix");
    var ok;
    try {
        ok = ~matLoadFile.(path)
    } { |e|
        ok = false;
        ("EXCEPTION loading " ++ name ++ ": " ++ e.class.name).postln
    };
    ok.if(
        { nOK = nOK + 1 },
        {
            nFail = nFail + 1;
            pass = false;
            ("FAIL load: " ++ name).postln
        }
    )
};

(nOK == 28).not.if({
    pass = false;
    ("FAIL count: expected 28, got " ++ nOK ++ " OK, " ++ nFail ++ " failed").postln
}, {
    ("OK: " ++ nOK ++ "/28 presets loaded").postln
});

// -- 2. Load techno_drive specifically and assert demo bindings parsed --
{
    var path = ~matPresetDir +/+ "techno_drive.matrix";
    ~matVoices.do { |v| ~matVoiceMods[v] = []; ~matVoicePoses[v] = [] };
    try {
        ~matLoadFile.(path)
    } { |e|
        pass = false;
        ("EXCEPTION reloading techno_drive: " ++ e.class.name).postln
    };
    // acid (vi=5) must have one mod binding (bodyVitesse->cutoff, depth 0.6)
    (~matVoiceMods[\acid].notNil and: { ~matVoiceMods[\acid].size == 1 }).if({
        var b = ~matVoiceMods[\acid][0];
        ((b[\source] == \bodyVitesse) and: { b[\target] == \cutoff }).if(
            { "OK techno_drive acid voiceMods".postln },
            {
                pass = false;
                ("FAIL techno_drive acid mod: " ++ b).postln
            }
        )
    }, {
        pass = false;
        ("FAIL techno_drive acid voiceMods empty/nil: "
            ++ (~matVoiceMods[\acid])).postln
    });
    // kick (vi=0) must have one pose binding (danse / trigger)
    (~matVoicePoses[\kick].notNil and: { ~matVoicePoses[\kick].size == 1 }).if({
        var b = ~matVoicePoses[\kick][0];
        ((b[\poseId] == \danse) and: { b[\action] == \trigger }).if(
            { "OK techno_drive kick voicePoses".postln },
            {
                pass = false;
                ("FAIL techno_drive kick pose: " ++ b).postln
            }
        )
    }, {
        pass = false;
        ("FAIL techno_drive kick voicePoses empty/nil: "
            ++ (~matVoicePoses[\kick])).postln
    })
}.value;

pass.if(
    { "VALIDATE PASS".postln },
    { "VALIDATE FAIL".postln }
);
0.exit;
)
