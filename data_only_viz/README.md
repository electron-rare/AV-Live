# data_only_viz

Python + Metal visualiser for the AV-Live data-only patch.

## Hand features OSC

`/pose/hands [pid=0, lx, ly, lopen, lspeed, rx, ry, ropen, rspeed, dist]`

- Emitted once per pipeline tick by `pose_bridge.send_hands` to sclang `:57121`.
- L = leftmost hand on screen, R = rightmost; absent hand -> its 4 floats are 0.
- Ranges: positions/openness/dist in [0,1]; speed >= 0 (normalized units/frame).
- Consumed by SuperCollider `~handFeat` (data_only) and the Metal renderer uniforms.
- Multi-person is not yet carried (pid is always 0).
