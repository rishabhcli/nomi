#!/usr/bin/env python3
"""Animation smoothness analysis over an extracted frame sequence.

Computes per-frame mean-absolute-difference (MAD) in the notch region and
grades the motion:
  - smooth spring: one contiguous hump of diffs that decays to ~0
  - glitch: a diff spike AFTER motion settled, a dead gap mid-motion
            (dropped frames), or a reversal flash (huge single-frame spike
            >> neighbors)
Usage: analyze-frames.py <frames-dir> <label> [--crop x,y,w,h]
Exit 0 = smooth, 1 = glitchy (details printed).
"""
import sys, os, glob
from PIL import Image, ImageChops, ImageStat

def main():
    d = sys.argv[1]
    label = sys.argv[2] if len(sys.argv) > 2 else "seq"
    crop = None
    if "--crop" in sys.argv:
        x, y, w, h = map(int, sys.argv[sys.argv.index("--crop") + 1].split(","))
        crop = (x, y, x + w, y + h)

    files = sorted(glob.glob(os.path.join(d, "*.png")))
    if len(files) < 8:
        print(f"[{label}] only {len(files)} frames — need ≥8"); sys.exit(1)

    prev = None
    diffs = []
    for f in files:
        im = Image.open(f).convert("L")
        if crop: im = im.crop(crop)
        # downscale for speed + noise tolerance
        im = im.resize((im.width // 4 or 1, im.height // 4 or 1))
        if prev is not None:
            mad = ImageStat.Stat(ImageChops.difference(im, prev)).mean[0]
            diffs.append(mad)
        prev = im

    peak = max(diffs)
    if peak < 0.8:
        print(f"[{label}] no motion detected (peak diff {peak:.2f}) — nothing to grade")
        sys.exit(1)

    # Normalize; find the motion window (diff > 10% of peak).
    n = [x / peak for x in diffs]
    active = [i for i, x in enumerate(n) if x > 0.10]
    start, end = active[0], active[-1]
    issues = []

    # 1. Dead gaps mid-motion (dropped/hitched frames): inside the motion
    #    window, ≥3 consecutive near-zero frames then motion resumes.
    gap = 0
    for i in range(start, end + 1):
        if n[i] < 0.05:
            gap += 1
            if gap >= 3:
                issues.append(f"hitch: {gap} dead frames at {i - gap + 1}..{i} inside motion")
                gap = 0
        else:
            gap = 0

    # 2. Late spike: a burst after the animation settled (≥5 quiet frames
    #    then a jump >35% of peak) = pop/flash after settle.
    quiet = 0
    for i in range(end + 1, len(n)):
        if n[i] < 0.05: quiet += 1
        elif quiet >= 5 and n[i] > 0.35:
            issues.append(f"late spike at frame {i}: {n[i] * peak:.1f} after {quiet} quiet frames")
            quiet = 0

    # 3. Single-frame reversal flash: one frame >3x both neighbors and >60% peak.
    for i in range(1, len(n) - 1):
        if n[i] > 0.6 and n[i] > 3 * n[i - 1] and n[i] > 3 * n[i + 1] and n[i - 1] > 0.02:
            issues.append(f"flash at frame {i}: {n[i] * peak:.1f} vs neighbors {n[i-1]*peak:.1f}/{n[i+1]*peak:.1f}")

    curve = " ".join(f"{x:.2f}" for x in n)
    print(f"[{label}] frames={len(files)} peak_mad={peak:.1f} motion={start}..{end}")
    print(f"[{label}] curve: {curve}")
    if issues:
        for msg in issues: print(f"[{label}] GLITCH — {msg}")
        sys.exit(1)
    print(f"[{label}] SMOOTH")
    sys.exit(0)

if __name__ == "__main__":
    main()
