// Registered body gestures. FX/dramatic family here; harmony/melody appended in
// later tasks. Loaded after the morceaux (needs ~ccGestureAdd, ~ccFire, ~ccMaster).
(
var meanY = { |a, b| ((a[\y] ? 0.5) + (b[\y] ? 0.5)) * 0.5 };

// JUMP — body center rose fast then we fire (one-shot)
~ccGestureAdd.((name:\jump, family:\fx, hold:0, cooldown:0.7,
    detect: { |pose, prev|
        ((pose[\center][\cy] ? 0.5) < ((prev[\center][\cy] ? 0.5) - 0.06)) },
    fire: { ~ccFire.(\crash); ~ccMaster[\dip].() }));

// STOMP — an ankle dropped fast (planted)
~ccGestureAdd.((name:\stomp, family:\fx, hold:0, cooldown:0.35,
    detect: { |pose, prev|
        var s = pose[\skel]; var p = prev[\skel];
        (s.notNil and: { p.notNil }) and: {
            var dl = (s[\ankL][\y] ? 0.95) - (p[\ankL][\y] ? 0.95);
            var dr = (s[\ankR][\y] ? 0.95) - (p[\ankR][\y] ? 0.95);
            dl.max(dr) > 0.05 } },
    fire: { ~ccFire.(\kick) }));

// SQUAT (held) — hips near knees -> breakdown sweep down; release sweeps back
~ccGestureAdd.((name:\squat, family:\fx, hold:0.6, cooldown:0.2,
    detect: { |pose, prev|
        var s = pose[\skel];
        s.notNil and: { meanY.(s[\hipL], s[\hipR]) > (meanY.(s[\kneeL], s[\kneeR]) - 0.10) } },
    fire: { ~ccMaster[\filterTo].(450, 1.0) },
    release: { ~ccMaster[\filterTo].(20000, 1.5) }));

// SPIN — shoulders swapped x sign vs prev -> stutter
~ccGestureAdd.((name:\spin, family:\fx, hold:0, cooldown:1.2,
    detect: { |pose, prev|
        var s = pose[\skel]; var p = prev[\skel];
        (s.notNil and: { p.notNil }) and: {
            var now = (s[\shR][\x] ? 0.6) - (s[\shL][\x] ? 0.4);
            var was = (p[\shR][\x] ? 0.6) - (p[\shL][\x] ? 0.4);
            (now.sign != was.sign) and: { was.abs > 0.05 } } },
    fire: { ~ccMaster[\stutterOn].(0.9) }));

// T-POSE (held) — wrists wide at shoulder height -> swell
~ccGestureAdd.((name:\tpose, family:\fx, hold:0.8, cooldown:2.0,
    detect: { |pose, prev|
        var s = pose[\skel]; var w = ~poseWrist.notNil.if({ ~poseWrist.values.detect({|v| v.notNil}) });
        (s.notNil and: { w.notNil }) and: {
            (((w[\rx] ? 0.5) - (w[\lx] ? 0.5)).abs > 0.4)
            and: { ((w[\ry] ? 0.5) - (s[\shR][\y] ? 0.35)).abs < 0.14 } } },
    fire: { ~ccFire.(\swell) }));

"[data-only/concert_gestures] fx gestures registered".postln;
)
