"""Block diagram of the extended study (Grafik 2, 14.11.2026): policies, shared command interface, three plants.

Schematic, no data. Same style as fig/src/plot_pipeline.py in the paper repo (fig:pipeline). Content:
  policies   RL agent (PPO, reward with base term or base budget via Lagrange multiplier, X1) and the model-based
             controller (generalized Jacobian, null space with weight beta, inverts the command chain, X2)
  interface  saturation, IIR filter, rate limiter at the agent step (40 Hz), identical for all policies and plants
  plants     free-floating Simscape model (training, evaluation protocol X0.1), kinematic free-floating simulator
             (X0.2, <= 0.45 mm against Simscape, about 12 times faster), fixed-base Kinova Gen3 with virtual base
             emulation (X3, base states computed from the measured joints)
  metrics    EE error RMS, largest base rotation, follows the path (X0.1), compared with the controller front (X2.2)
Output (Matlab repo): media/figures/study_design.{pdf,png}

Usage: python evaluation/media/plot_study_design.py
"""
import os

import matplotlib
from matplotlib.patches import FancyArrowPatch, FancyBboxPatch

matplotlib.use('Agg')
import matplotlib.pyplot as plt  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, '..', '..', 'media', 'figures')
os.makedirs(OUT, exist_ok=True)
INK, INK2 = '#0b0b0b', '#52514e'
C_SIM, C_KIN, C_HW, C_SHARED, C_POL = '#e8f1fb', '#eef5ec', '#fdeee6', '#f2f2ef', '#ffffff'
BLUE, GREEN, ORANGE = '#1d5aa8', '#2f7a3a', '#a8471d'

plt.rcParams.update({'pdf.fonttype': 42, 'ps.fonttype': 42,
                     'font.family': ['Arial', 'Liberation Sans', 'DejaVu Sans'], 'font.size': 7})
fig = plt.figure(figsize=(7.0, 3.0))
ax = fig.add_axes([0, 0, 1, 1])
ax.set_xlim(-1.5, 102)
ax.set_ylim(0, 43)
ax.axis('off')


def box(x0, y0, w, h, text, fc, ec=INK2, ls='-', fs=6.5):
    ax.add_patch(FancyBboxPatch((x0, y0), w, h, boxstyle='round,pad=0.25,rounding_size=0.8', fc=fc, ec=ec,
                                lw=0.7, ls=ls))
    lines = text.split('\n')
    ax.text(x0 + w / 2, y0 + h / 2 + 0.95 * (len(lines) - 1), lines[0], ha='center', va='center', fontsize=fs,
            fontweight='bold')
    if len(lines) > 1:
        ax.text(x0 + w / 2, y0 + h / 2 - 1.05, '\n'.join(lines[1:]), ha='center', va='center', fontsize=fs - 0.5,
                color=INK, linespacing=1.15)


def arrow(p, q, c=INK2, conn='arc3', lw=0.8):
    ax.add_patch(FancyArrowPatch(p, q, arrowstyle='-|>', mutation_scale=7, color=c, lw=lw, connectionstyle=conn,
                                 shrinkA=0, shrinkB=0))


# Spaltenueberschriften
for x, t in [(11.5, 'Policies'), (48.75, 'Shared command interface'), (88.0, 'Plants')]:
    ax.text(x, 40.6, t, fontsize=7.5, fontweight='bold', ha='center', va='center', color=INK)

# Policies
box(1.5, 23.5, 20, 9.5, 'RL agent (PPO)\nreward: tracking plus a base\nterm, or a base budget\n(Lagrange multiplier)', C_POL)
box(1.5, 9.5, 20, 9.5, 'Model-based controller\ngeneralized Jacobian,\nnull space with weight β,\ninverts the command chain', C_POL)
ax.text(11.5, 21.25, 'same observation, same outputs', fontsize=6, color=INK2, ha='center', va='center',
        style='italic')

# Gemeinsame Befehlskette
ax.add_patch(FancyBboxPatch((27.0, 13.5), 43.5, 15.5, boxstyle='round,pad=0.3,rounding_size=1.0', fc=C_SHARED,
                            ec=INK2, lw=0.7, ls=(0, (4, 2))))
ax.text(48.75, 27.0, 'identical for every policy and plant, computed with the training step (25 ms)', fontsize=6.2,
        color=INK2, ha='center', va='center', style='italic')
xs = [29.0, 43.0, 57.0]
labels = ['Saturation\nper joint', 'IIR filter\nfirst-order\nlow-pass', 'Rate limiter\nacceleration\nbound']
for x, t in zip(xs, labels):
    box(x, 16.0, 11.5, 8.5, t, 'white')
for a, b in zip(xs[:-1], xs[1:]):
    arrow((a + 11.5 + 0.3, 20.25), (b - 0.3, 20.25))
arrow((21.8, 28.25), (28.7, 22.0), conn='arc3,rad=-0.15')
arrow((21.8, 14.25), (28.7, 18.5), conn='arc3,rad=0.15')

# Strecken
box(76.0, 29.0, 24.0, 8.0, 'Free-floating model (Simscape)\ntraining and evaluation,\n21 episodes per agent', C_SIM)
box(76.0, 17.5, 24.0, 8.0, 'Kinematic free-floating simulator\n≤ 0.45 mm to Simscape, ~12× faster,\ncontroller sweeps, robustness', C_KIN)
box(76.0, 6.0, 24.0, 8.0, 'Kinova Gen3, fixed base\nsafety layer, loop at 20 Hz\n(rate mismatch), virtual base', C_HW)
for y in (33.0, 21.5, 10.0):
    arrow((69.0 + 2.0, 20.25), (75.7, y), conn='arc3,rad=%.2f' % (0.0 if y == 21.5 else (-0.12 if y > 21.5 else 0.12)))
ax.text(88.0, 3.4, 'base states computed from the measured joints', fontsize=6, color=ORANGE, ha='center',
        va='center', style='italic')

# Rueckfuehrung: Beobachtung
ax.plot([100.6, 100.6], [10.0, 37.9], color=INK2, lw=0.8)
for y in (33.0, 21.5, 10.0):
    ax.plot([100.3, 100.6], [y, y], color=INK2, lw=0.8)
ax.plot([100.6, -0.4, -0.4], [37.9, 37.9, 14.25], color=INK2, lw=0.8)
arrow((-0.4, 28.25), (1.2, 28.25))
arrow((-0.4, 14.25), (1.2, 14.25))
ax.text(56.0, 37.9, 'observation (29): end-effector error, joints, base states (simulated or emulated)',
        fontsize=6.5, color=INK2, ha='center', va='center', bbox=dict(fc='white', ec='none', pad=0.6))

# Kennzahlen
ax.add_patch(FancyBboxPatch((27.0, 3.0), 43.5, 6.0, boxstyle='round,pad=0.3,rounding_size=1.0', fc='white',
                            ec=INK2, lw=0.7))
ax.text(48.75, 7.3, 'Metrics per agent and controller', fontsize=6.5, fontweight='bold', ha='center', va='center')
ax.text(48.75, 4.6, 'end-effector error (RMS)  ·  largest base rotation  ·  follows the path\n'
                    '→ compared with the controller front (error vs. base rotation)', fontsize=6, ha='center',
        va='center', color=INK, linespacing=1.2)

for ext in ('pdf', 'png'):
    fig.savefig(os.path.join(OUT, 'study_design.' + ext), dpi=300)
print('saved', os.path.normpath(os.path.join(OUT, 'study_design.pdf')))
