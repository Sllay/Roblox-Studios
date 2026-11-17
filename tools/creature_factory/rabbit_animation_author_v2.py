"""S09.10 Rabbit V2 locomotion: paired hind-leg hops, four-paw bounds, two idles.

Keep the verified 19-bone source GLB intact. Reuse the serialiser and rig
hierarchy from rabbit_animation_author; never change the original six receipts.
No Place writes occur here.
"""
from __future__ import annotations

import math
import rabbit_animation_author as original

CLIPS = {
    "Idle": (3.0, 24, True, 0),
    "Walk": (0.62, 24, True, 1),
    "Run": (0.50, 28, True, 1),
    "ScratchEar": (1.55, 32, False, 2),
}


def smooth(x: float) -> float:
    x = max(0.0, min(1.0, x))
    return x * x * (3.0 - 2.0 * x)


def pulse(t: float, start: float, peak: float, end: float) -> float:
    assert start < peak < end
    if t <= start or t >= end:
        return 0.0
    if t < peak:
        return smooth((t - start) / (peak - start))
    return 1.0 - smooth((t - peak) / (end - peak))


def airtime(t: float, start: float, end: float) -> float:
    if t <= start or t >= end:
        return 0.0
    # Grounded at either end, continuous at takeoff and touchdown.
    return math.sin(math.pi * (t - start) / (end - start)) ** 2


def motion(clip: str, name: str, t: float):
    tau = 2.0 * math.pi * t
    ax = ay = az = y = 0.0
    side = -1.0 if name.endswith("_L") else 1.0
    if clip == "Idle":
        if name == "Chest":
            ax = 0.025 * math.sin(tau)
        elif name == "Head":
            ax = 0.026 * math.sin(tau + 0.5) - 0.026 * math.sin(0.5)
            az = 0.013 * math.sin(tau)
        elif name.startswith("Ear_"):
            ax = 0.035 * math.sin(tau - 0.3) + 0.035 * math.sin(0.3)
            az = side * 0.028 * math.sin(tau)
        elif name == "Tail":
            ay = 0.022 * math.sin(tau)
    elif clip in ("Walk", "Run"):
        fast = clip == "Run"
        launch = pulse(t, 0.035, 0.15 if fast else 0.17, 0.29)
        flight = airtime(t, 0.13 if fast else 0.18, 0.73 if fast else 0.70)
        land = pulse(t, 0.61, 0.745, 0.87)
        recover = pulse(t, 0.81, 0.905, 0.99)
        if name == "Root":
            y = (0.37 if fast else 0.15) * flight - (0.045 if fast else 0.021) * launch - 0.025 * land
        elif name == "Pelvis":
            ax = -0.10 * launch + (0.13 if fast else 0.065) * flight - 0.045 * recover
        elif name == "Chest":
            ax = 0.085 * launch - (0.18 if fast else 0.085) * flight + 0.10 * land
        elif name == "Head":
            ax = -0.055 * launch + 0.070 * flight - 0.035 * land
        elif name.startswith("Hip_"):
            # Crucial: both hind legs propel in the SAME phase; no left/right steps.
            ax = -(0.48 if fast else 0.27) * launch + (0.41 if fast else 0.25) * flight - 0.16 * land
        elif name.startswith("Shin_"):
            ax = (0.58 if fast else 0.31) * launch - (0.47 if fast else 0.29) * flight + 0.21 * land
        elif name.startswith("HindPaw_"):
            ax = -0.16 * launch + (0.24 if fast else 0.12) * flight - 0.13 * land
        elif name.startswith("Shoulder_"):
            # Forelegs reach into the flight and brace the front landing.
            ax = (0.34 if fast else 0.16) * flight - (0.46 if fast else 0.24) * land
        elif name.startswith("Forearm_"):
            ax = -(0.26 if fast else 0.13) * flight + (0.41 if fast else 0.20) * land
        elif name.startswith("FrontPaw_"):
            ax = 0.18 * flight - 0.22 * land
        elif name.startswith("Ear_"):
            ax = -(0.23 if fast else 0.11) * flight + 0.10 * land
            az = side * 0.052 * flight
        elif name == "Tail":
            ax = 0.095 * flight
    elif clip == "ScratchEar":
        # One hind paw reaches behind the left ear. Three small rakes draw
        # the ear down; the opposite hind paw remains planted. Entirely local
        # rotations: no vertex changes, skin breaks or detached paw translations.
        env = math.sin(math.pi * t) ** 2
        strokes = smooth((t - 0.28) / 0.09) * (1.0 - smooth((t - 0.82) / 0.10))
        rake = math.sin((t - 0.34) * (6.0 * math.pi / 0.48)) * strokes
        if name == "Root":
            y = -0.038 * env
        elif name == "Pelvis":
            az = 0.055 * env
        elif name == "Chest":
            ax = 0.06 * env
        elif name == "Head":
            az = -0.10 * env
            ax = 0.07 * env
        elif name == "Hip_L":
            ax = -1.27 * env
            az = -0.25 * env
        elif name == "Shin_L":
            ax = 1.58 * env + 0.16 * rake
        elif name == "HindPaw_L":
            ax = -0.90 * env - 0.24 * rake
        elif name == "Ear_L":
            ax = 0.61 * env + 0.16 * rake
            az = -0.17 * env
        elif name == "Ear_R":
            ax = -0.035 * env
        elif name == "Tail":
            ay = 0.025 * env
    else:
        raise ValueError("Only the four replacement clips are supported")
    return original.cframe_xyz(ax, ay, az, y)


def main():
    # Isolate variant changes to the invocation. Original author is retained
    # for legacy receipts and deterministic, replayable evidence.
    original.CLIPS = CLIPS
    original.motion = motion
    original.main()


if __name__ == "__main__":
    main()
