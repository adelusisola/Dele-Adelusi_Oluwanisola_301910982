#!/usr/bin/env bash
# Median and range of the 5 runs before and after indexing, and the pages read (buffers) by each saved plan.
python3 -I - <<'PY'
import re, statistics
def times(phase):
    out = {}
    for line in open(f"plans/{phase}/Dele-Adelusi_Oluwanisola_301910982_times.csv"):
        q, *v = line.strip().split(",")
        out[q] = [float(x) for x in v]
    return out
def buffers(phase, q):
    m = re.search(r"Buffers: (.*)", open(f"plans/{phase}/Dele-Adelusi_Oluwanisola_301910982_{q}.txt").read())
    return sum(int(n) for n in re.findall(r"(?:hit|read)=(\d+)", m.group(1))) if m else 0
b, a = times("before"), times("after")
fmt = lambda v: f"{statistics.median(v):.2f} ({min(v):.2f}-{max(v):.2f})"
print(f"{'query':<6}{'before ms: median (min-max)':<32}{'after ms: median (min-max)':<32}{'pages before':>13}{'pages after':>13}")
for q in sorted(b):
    print(f"{q:<6}{fmt(b[q]):<32}{fmt(a[q]):<32}{buffers('before', q):>13}{buffers('after', q):>13}")
PY
