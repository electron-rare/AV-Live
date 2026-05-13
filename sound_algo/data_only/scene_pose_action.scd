// =====================================================================
//  scene_pose_action.scd -- pilote les FX live a partir de l'action_head.
//
//  Necessite : data_feeds.scd deja charge (handlers OSCdef \poseAction,
//  \poseKin, \poseEnter, \poseLeave). Les dicts ~poseState et ~poseKin
//  doivent etre populates en temps reel par data_only_viz.action_head_pub.
//
//  Mapping :
//    speed (m/s mean joint)       -> drive amount    0..1
//    accel (m/s2)                 -> filter cutoff   200 Hz..6 kHz
//    symmetry (-1..1)             -> stereo width    0..1
//    label argmax (0=debout, 1=assise, 2=danse) :
//      - debout  -> reverb mid, kick on, melody pad
//      - assise  -> pad ambient, kick off, lo-fi
//      - danse   -> drive max, kick punchy, acid lead
//
//  Usage live (a evaluer bloc par bloc dans le SC IDE) :
//      [0] SETUP : declare le helper ~mapPoseToFx + lance la Routine.
//      [1] START : ~scenePoseAction.start
//      [2] STOP  : ~scenePoseAction.stop
//      [3] TWEAK : ajuster les seuils dans ~paConfig
// =====================================================================

// [0] SETUP -----------------------------------------------------------
(
~paConfig = (
	speedMin:      0.0,    speedMax:    0.8,
	accelMin:      0.0,    accelMax:    3.0,
	cutoffMin:     200,    cutoffMax:   6000,
	rate:          10,     // refresh Hz
);

~mapPoseToFx = {
	var avgSpeed = 0, avgAccel = 0, avgSym = 0, avgProbs = [0, 0, 0];
	var n = max(1, ~poseKin.size);
	var labelIdx;

	~poseKin.values.do { |kin|
		avgSpeed = avgSpeed + (kin[\speed] ? 0);
		avgAccel = avgAccel + (kin[\accel] ? 0);
		avgSym   = avgSym   + (kin[\symmetry] ? 0);
	};
	avgSpeed = avgSpeed / n;
	avgAccel = avgAccel / n;
	avgSym   = avgSym   / n;

	~poseState.values.do { |ps|
		var p = ps[\probs] ? [0, 0, 0];
		avgProbs = avgProbs.collect { |v, i| v + (p[i] ? 0) };
	};
	avgProbs = avgProbs.collect { _ / n };
	labelIdx = avgProbs.maxIndex ? 0;

	// Drive + filter + width
	if (~fxDrive.notNil) {
		~fxDrive.(avgSpeed.linlin(~paConfig[\speedMin], ~paConfig[\speedMax], 0, 1));
	};
	if (~fxCut.notNil) {
		~fxCut.(avgAccel.linexp(~paConfig[\accelMin], ~paConfig[\accelMax],
								~paConfig[\cutoffMin], ~paConfig[\cutoffMax]));
	};
	if (~fxSt.notNil) { ~fxSt.(avgSym.linlin(-1, 1, 0, 1)) };

	// Label-driven track switch (smooth crossfade between presets)
	switch (labelIdx,
		0, {
			if (~fxComp.notNil) { ~fxComp.(0.7) };
			if (~fxRev.notNil)  { ~fxRev.(0.4) };
		},
		1, {
			if (~fxComp.notNil) { ~fxComp.(0.3) };
			if (~fxRev.notNil)  { ~fxRev.(0.6) };
		},
		2, {
			if (~fxComp.notNil) { ~fxComp.(0.9) };
			if (~fxRev.notNil)  { ~fxRev.(0.2) };
			if (~fxDrive.notNil){ ~fxDrive.(avgSpeed.linlin(0, 0.6, 0.3, 1.0)) };
		}
	);

	[labelIdx, avgSpeed.round(0.01), avgAccel.round(0.01),
	 avgSym.round(0.01)];
};

~scenePoseAction = ~scenePoseAction ?? {
	(
		running: false,
		routine: nil,
		start: {
			if (~scenePoseAction[\running]) {
				"[scene_pose_action] already running".postln;
			} {
				~scenePoseAction[\running] = true;
				~scenePoseAction[\routine] = Routine({
					inf.do {
						var snapshot = ~mapPoseToFx.();
						if (~scenePoseAction[\verbose] ? false) {
							("[pose] label=" ++ snapshot[0]
							 ++ " s=" ++ snapshot[1]
							 ++ " a=" ++ snapshot[2]
							 ++ " sym=" ++ snapshot[3]).postln;
						};
						(1 / ~paConfig[\rate]).wait;
					};
				}).play;
				"[scene_pose_action] STARTED".postln;
			};
		},
		stop: {
			~scenePoseAction[\routine] !? { |r| r.stop };
			~scenePoseAction[\routine] = nil;
			~scenePoseAction[\running] = false;
			"[scene_pose_action] STOPPED".postln;
		},
		verbose: false,
	)
};

"[OK] SETUP scene_pose_action".postln;
)

// [1] START -----------------------------------------------------------
// ~scenePoseAction[\verbose] = true;   // optionnel : log chaque tick
// ~scenePoseAction[\start].();

// [2] STOP ------------------------------------------------------------
// ~scenePoseAction[\stop].();

// [3] TWEAK ------------------------------------------------------------
// ~paConfig[\speedMax] = 1.2;
// ~paConfig[\rate]     = 20;
