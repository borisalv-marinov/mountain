# Generates the Mountain ridgeline wallpaper SVGs (dark|light); the output SVGs are committed, the generator is not run at build.
import math, random, sys

W, H, N = 3840, 2160, 56
TWIN = [(1620, 300, 0.6), (2200, 370, 1.0)]  # (x, half-width, height factor): left shorter, right taller

THEMES = {
    "dark": dict(sky=[(0, "#05070f"), (.55, "#0b1026"), (1, "#141c3d")], far=(0x6f, 0x8f, 0xd0), near=(0xe8, 0xf6, 0xff),
                 glow="#38bdf8", glow_op=.16, fade="#05070f", fade_op=.0, op=(.55, .95), moon="#e8f6ff"),
    "light": dict(sky=[(0, "#f4f7fb"), (.6, "#e9eff7"), (1, "#dfe8f3")], far=(0x94, 0xa8, 0xc4), near=(0x2b, 0x3a, 0x52),
                  glow="#38bdf8", glow_op=.12, fade="#dfe8f3", fade_op=.0, op=(.35, .95), moon="#ffffff"),
}

def mix(a, b, t):
    return "#%02x%02x%02x" % tuple(round(a[i] + (b[i] - a[i]) * t) for i in range(3))

def build(name):
    th = THEMES[name]
    rnd = random.Random(20240611)
    waves = [(rnd.uniform(.6, 1.0) / (k + 1) ** .7, (k + 1) * rnd.uniform(.9, 1.3) * math.pi * 2 / W * 1.25,
              rnd.uniform(0, 6.28), rnd.uniform(-.5, .5)) for k in range(7)]
    def terrain(x, t):
        s = 0
        for a, f, p, d in waves:
            v = math.sin(f * x + p + d * t * 22)
            s += a * ((1 - abs(v)) ** 1.6 - .4)  # ridged noise: sharp crests, soft saddles
        return s
    out = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="0 0 {W} {H}">']
    stops = "".join(f'<stop offset="{o}" stop-color="{c}"/>' for o, c in th["sky"])
    out.append(f'<defs><linearGradient id="bg" gradientUnits="userSpaceOnUse" x1="0" y1="0" x2="0" y2="{H}">{stops}</linearGradient>'
               f'<radialGradient id="gl" cx="0.5" cy="0.5" r="0.5"><stop offset="0" stop-color="{th["glow"]}" stop-opacity="{th["glow_op"]}"/>'
               f'<stop offset="1" stop-color="{th["glow"]}" stop-opacity="0"/></radialGradient></defs>')
    out.append(f'<rect width="{W}" height="{H}" fill="url(#bg)"/>')
    out.append(f'<ellipse cx="2000" cy="900" rx="1500" ry="900" fill="url(#gl)"/>')
    out.append(f'<circle cx="2960" cy="470" r="150" fill="url(#gl)"/><circle cx="2960" cy="470" r="46" fill="{th["moon"]}" fill-opacity="{.5 if name=="dark" else .8}"/>')
    step = 20
    xs = list(range(-40, W + 41, step))
    for i in range(N):
        t = i / (N - 1)
        base = H * (0.50 + 0.36 * t ** 0.85)
        amp = 110 + 70 * t
        env = 0.45 + 0.55 * math.sin(math.pi * min(1, t * 1.15 + .05)) ** .5  # keep far ridges lower-amplitude
        ys = []
        for x in xs:
            y = base - amp * (terrain(x, t) * .6) * (0.6 + 0.6 * t)
            # twin peak: nested triangles fading out with depth
            q = (t - .02) / .55
            if 0 <= q <= 1:
                for cx, hw, hf in TWIN:
                    tri = max(0, 1 - abs(x - cx) / (hw * (1 + .5 * q)))
                    y -= 600 * hf * (1 - q) ** .9 * tri
            ys.append(y)
        d = f"M{xs[0]} {ys[0]:.1f}"
        px, py = xs[0], round(ys[0], 1)
        for x, y in zip(xs[1:], ys[1:]):
            y = round(y, 1)
            d += f"l{x - px} {round(y - py, 1):g}"
            px, py = x, y
        d += f"L{W + 40} {H}L-40 {H}Z"
        col = mix(th["far"], th["near"], t ** .9)
        so = th["op"][0] + (th["op"][1] - th["op"][0]) * t ** .8
        sw = 1.3 + 1.0 * t
        out.append(f'<path d="{d}" fill="url(#bg)" stroke="{col}" stroke-opacity="{so:.2f}" stroke-width="{sw:.1f}" stroke-linejoin="round"/>')
    # quiet bottom band
    out.append(f'<linearGradient id="fd" gradientUnits="userSpaceOnUse" x1="0" y1="{H*.86}" x2="0" y2="{H}"><stop offset="0" stop-color="{th["fade"]}" stop-opacity="0"/>'
               f'<stop offset="1" stop-color="{th["fade"]}" stop-opacity="{.92 if name=="dark" else .85}"/></linearGradient>')
    out.append(f'<rect y="{H*.86}" width="{W}" height="{H*.14}" fill="url(#fd)"/>')
    out.append("</svg>")
    return "\n".join(out)

if __name__ == "__main__":
    sys.stdout.write(build(sys.argv[1] if len(sys.argv) > 1 else "dark"))
