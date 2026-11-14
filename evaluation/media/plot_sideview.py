"""Technical side view (Grafik 3, 14.11.2026): IK tracking without base term (R0) against the RL agent (D16 r4 s2).

Data: media/figures/sideview_data.mat from media_fig_sideview_data.m (ext_kinsim, planar half-circle, J2/J4/J6,
free-floating base 65 kg, nominal start). The motion lies in the x-z plane, the base rotates about y only, so the
side view shows the full base rotation. Everything to scale. The base angle is marked on an extended body axis.
Output: media/figures/sideview.{pdf,png}

Usage: python evaluation/media/plot_sideview.py
"""
import math
import os

import matplotlib
import numpy as np
import scipy.io as sio
from matplotlib.patches import Arc, Polygon

matplotlib.use('Agg')
import matplotlib.pyplot as plt  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
FIG = os.path.join(HERE, '..', '..', 'media', 'figures')
D = sio.loadmat(os.path.join(FIG, 'sideview_data.mat'), squeeze_me=True, struct_as_record=False)
INK, INK2, GRID = '#0b0b0b', '#52514e', '#c9c9c5'
C_PATH = '#2a78d6'
plt.rcParams.update({'pdf.fonttype': 42, 'ps.fonttype': 42,
                     'font.family': ['Arial', 'Liberation Sans', 'DejaVu Sans'], 'font.size': 7})


def fmt_deg(rad):
    m = round(math.degrees(abs(rad)) * 60)
    return '%d°%02d′' % (m // 60, m % 60)


def hull_xz(c):
    """Silhouette of the cube in the side view: convex hull of the eight corners projected to x-z."""
    p = np.c_[c[0, :], c[2, :]]
    p = p[np.lexsort((p[:, 1], p[:, 0]))]

    def cross2(a, b):
        return a[0] * b[1] - a[1] * b[0]

    def half(pts):
        h = []
        for q in pts:
            while len(h) >= 2 and cross2(h[-1] - h[-2], q - h[-2]) <= 0:
                h.pop()
            h.append(q)
        return h
    lo, up = half(p), half(p[::-1])
    return np.array(lo[:-1] + up[:-1])


def panel(ax, r, title):
    t = r.t
    n_end = len(t) - 1
    # Basis: Startlage gestrichelt, Endlage durchgezogen
    ax.add_patch(Polygon(hull_xz(r.corners[0]), closed=True, fc='none', ec=INK2, lw=0.7, ls=(0, (3, 2))))
    ax.add_patch(Polygon(hull_xz(r.corners[n_end]), closed=True, fc='#f2f2ef', ec=INK, lw=0.9, zorder=1))
    # Arm: fuenf Posen, hell nach dunkel
    times = np.linspace(0, t[-1], 5)
    for j, tt in enumerate(times):
        k = int(np.argmin(abs(t - tt)))
        P = r.joints[k][:, 1:]                      # ab der Montage (kinova_base_link) bis zum EE-Punkt
        g = 0.78 - 0.6 * j / (len(times) - 1)
        ax.plot(P[0], P[2], '-', color=(g, g, g), lw=1.6 if j == len(times) - 1 else 1.0, zorder=3,
                solid_capstyle='round')
        ax.plot(P[0], P[2], 'o', ms=2.2 if j == len(times) - 1 else 1.4, mfc='white', mec=(g, g, g), mew=0.6,
                zorder=4)
    # Bahn
    ax.plot(r.ref[:, 0], r.ref[:, 2], '--', color=INK, lw=0.8, zorder=5)
    ax.plot(r.ee[:, 0], r.ee[:, 2], '-', color=C_PATH, lw=1.3, zorder=6)
    # Basiswinkel: senkrechte Bezugslinie und mitgedrehte Koerperachse, Bogen mit Maß
    pb = r.joints[n_end][:, 0]
    th = r.pitch[n_end]
    L, rA = 1.98, 1.88                               # Achsen ueber die Bahn hinaus, Bogen oberhalb der Bahn
    ax.plot([0, 0], [0, L], '-', color=INK2, lw=0.5, zorder=2)
    ax.plot([pb[0], pb[0] + L * math.sin(th)], [pb[2], pb[2] + L * math.cos(th)], '-.', color=INK, lw=0.7,
            zorder=2)
    a0, a1 = sorted([90.0, 90.0 - math.degrees(th)])
    ax.add_patch(Arc((0, 0), 2 * rA, 2 * rA, theta1=a0, theta2=a1, color=INK, lw=0.9))
    ax.annotate(fmt_deg(th), xy=(rA * math.sin(th / 2), rA * math.cos(th / 2)), xytext=(-0.5, 1.9),
                fontsize=7.5, color=INK, fontweight='bold', va='center',
                arrowprops=dict(arrowstyle='-', lw=0.5, color=INK2))
    ax.set_title(title, fontsize=7.5, fontweight='bold', loc='left', pad=3)
    ax.text(-0.6, -0.62, 'end-effector error %.1f mm RMS\nlargest base rotation %s' % (1000 * r.rms,
            fmt_deg(r.ori_max)), fontsize=6.5, color=INK, va='top', linespacing=1.3)
    ax.set_xlim(-0.62, 0.62)
    ax.set_ylim(-0.86, 2.02)
    ax.set_aspect('equal')
    ax.axis('off')


fig, axs = plt.subplots(1, 2, figsize=(7.0, 4.6))
fig.subplots_adjust(left=0.02, right=0.98, top=0.91, bottom=0.01, wspace=0.05)
panel(axs[0], D['ik'], '(a) Inverse kinematics, base rotation ignored (R0)')
panel(axs[1], D['rl'], '(b) RL agent, tracking and base term (PPO, r4)')
# Maßstab und Legende
ax = axs[1]
ax.plot([0.35, 0.55], [-0.78, -0.78], '-', color=INK, lw=1.0)
ax.plot([0.35, 0.35], [-0.8, -0.76], '-', color=INK, lw=1.0)
ax.plot([0.55, 0.55], [-0.8, -0.76], '-', color=INK, lw=1.0)
ax.text(0.45, -0.74, '0.2 m', ha='center', va='bottom', fontsize=6.5)
fig.legend(handles=[plt.Line2D([], [], color=INK, ls='--', lw=0.8, label='reference path'),
                    plt.Line2D([], [], color=C_PATH, lw=1.3, label='end-effector path'),
                    plt.Line2D([], [], color=INK2, lw=0.7, ls=(0, (3, 2)), label='base at start'),
                    plt.Line2D([], [], color=INK, lw=0.7, ls='-.', label='base axis at the end'),
                    plt.Line2D([], [], color=(0.5, 0.5, 0.5), lw=1.0, marker='o', ms=1.6, mfc='white',
                               label='arm at 0, 2.1, 4.3, 6.4, 8.5 s (light to dark)')],
           loc='upper center', ncol=5, frameon=False, fontsize=6.3, handlelength=2.2, columnspacing=1.2,
           bbox_to_anchor=(0.5, 1.0))
for ext in ('pdf', 'png'):
    fig.savefig(os.path.join(FIG, 'sideview.' + ext), dpi=300)
print('saved', os.path.normpath(os.path.join(FIG, 'sideview.pdf')))
