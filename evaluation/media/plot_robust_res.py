"""Robustness of residual RL against C2 per scenario (Grafik 2, 15.11.2026).

Data (no new runs), data/simulation/extension:
- Seeds 1-10: X7_C_robust_20261115_061011_summary.csv, C2 from X7_C_posthoc_robust_20261115_104248_summary.csv
- Seeds 11-20: X7_T2_robust_20261115_145114_summary.csv (contains C2)
Measure as in RESULTS X7.1/X7.3: J = RMS / 8.99 mm + ori_max / 12.98 mrad (R nominal). Per scenario the change of J
against C2 in percent: median over the 10 seeds of each group (as in RESULTS), bar = interquartile range over all
20 seeds (each seed against C2). Left of zero: residual better.
Check against RESULTS X7.3: 20/26 and 21/26 better, median -4.9 % and -5.2 % (asserted below).
Output: media/figures/robust_res_{paper,slide}.{pdf,png}

Usage: python evaluation/media/plot_robust_res.py
"""
import os

import matplotlib
import numpy as np
import pandas as pd

matplotlib.use('Agg')
import matplotlib.pyplot as plt  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.join(HERE, '..', '..')
DD = os.path.join(ROOT, 'data', 'simulation', 'extension')
FIG = os.path.join(ROOT, 'media', 'figures')
INK, INK2, GRID, BAND = '#0b0b0b', '#52514e', '#d9d9d5', '#c9c9c5'
C1, C2C = '#2a78d6', '#eb6834'
plt.rcParams.update({'pdf.fonttype': 42, 'ps.fonttype': 42,
                     'font.family': ['Arial', 'Liberation Sans', 'DejaVu Sans']})
R_NOM, O_NOM = 0.00898689144653296, 0.0129815649533335

LABELS = {
    'nominal': 'Nominal',
    'mass_0.25': 'Base mass and inertia ×0.25', 'mass_0.5': 'Base mass and inertia ×0.5',
    'mass_0.75': 'Base mass and inertia ×0.75', 'mass_1.5': 'Base mass and inertia ×1.5',
    'mass_2': 'Base mass and inertia ×2', 'inertia_0.5': 'Base inertia ×0.5', 'inertia_2': 'Base inertia ×2',
    'links_0.8': 'Link masses ×0.8', 'links_1.2': 'Link masses ×1.2',
    'mount_x+5cm': 'Mount offset x +5 cm', 'mount_x-5cm': 'Mount offset x −5 cm',
    'mount_z+5cm': 'Mount offset z +5 cm',
    'delay_25ms': 'Delay +25 ms', 'delay_50ms': 'Delay +50 ms', 'gain_0.9': 'Command gain ×0.9',
    'gain_1.1': 'Command gain ×1.1', 'servo_tau50ms': 'Servo lag 50 ms',
    'noise_1x': 'Sensor noise ×1', 'noise_3x': 'Sensor noise ×3',
    'bias_ori_10mrad': 'Base attitude bias 0°34′', 'bias_ee_5mm': 'End-effector bias 5 mm',
    'pose_2deg': 'Start pose ±2°', 'drift_y+2mrad': 'Base drift +0.11°/s about y',
    'drift_y-2mrad': 'Base drift −0.11°/s about y', 'drift_x2mrad': 'Base drift 0.11°/s about x',
}
GROUPS = [('nominal', 'Nominal'), ('model', 'Model errors'), ('actuator', 'Actuator'), ('sensor', 'Sensor'),
          ('initial', 'Initial state')]


def jval(df):
    return df.rms_ee / R_NOM + df.ori_max / O_NOM


def load():
    a = pd.read_csv(os.path.join(DD, 'X7_C_robust_20261115_061011_summary.csv'))
    ph = pd.read_csv(os.path.join(DD, 'X7_C_posthoc_robust_20261115_104248_summary.csv'))
    b = pd.read_csv(os.path.join(DD, 'X7_T2_robust_20261115_145114_summary.csv'))
    c2a = ph[ph.subject == 'C2'].set_index('scenario')
    c2b = b[b.subject == 'C2'].set_index('scenario')
    assert np.allclose(jval(c2a).sort_index(), jval(c2b).sort_index()), 'C2 differs between the two files'
    jc = jval(c2b)
    rows = []
    for seeds, df in (('1-10', a), ('11-20', b)):
        r = df[df.group == 'res_res'].copy()
        assert r.subject.nunique() == 10 and (r.follows_all == 1).all()
        r['J'] = jval(r)
        r['d'] = 100 * (r.J / jc.reindex(r.scenario).values - 1)
        r['seeds'] = seeds
        rows.append(r)
    r = pd.concat(rows)
    sg = r[['scenario', 'sgroup']].drop_duplicates().set_index('scenario').sgroup
    med = {}
    for seeds in ('1-10', '11-20'):
        m = r[r.seeds == seeds].groupby('scenario').J.median()
        med[seeds] = 100 * (m / jc.reindex(m.index) - 1)
    # Check against RESULTS X7.3
    assert (med['1-10'] < 0).sum() == 20 and (med['11-20'] < 0).sum() == 21
    assert abs(np.median(med['1-10']) + 4.94) < 0.05 and abs(np.median(med['11-20']) + 5.17) < 0.05
    q = r.groupby('scenario').d.quantile([0.25, 0.75]).unstack()
    return med, q, sg


def plot(med, q, sg, size, fs, ms, name):
    order, ypos, heads = [], [], []
    y = 0.0
    for g, title in GROUPS:
        sc = [s for s in sg.index if sg[s] == g]
        sc.sort(key=lambda s: (med['1-10'][s] + med['11-20'][s]) / 2)
        if g != 'nominal':
            y += 0.55
            heads.append((y, title))
            y += 0.85
        for s in sc:
            order.append(s)
            ypos.append(y)
            y += 1
    ypos = np.array(ypos)
    fig, ax = plt.subplots(figsize=size)
    fig.patch.set_facecolor('white')
    ax.set_facecolor('white')
    xl = (-22, 15)
    ax.axvspan(xl[0], 0, color='#f3f3f1', zorder=0, lw=0)
    ax.axvline(0, color=INK, lw=0.9, zorder=2)
    for yy, s in zip(ypos, order):
        ax.plot([q.loc[s, 0.25], q.loc[s, 0.75]], [yy, yy], color=BAND, lw=ms * 0.55, solid_capstyle='round',
                zorder=1)
    h1 = ax.plot([med['1-10'][s] for s in order], ypos - 0.13, 'o', ms=ms, color=C1, mec='white', mew=0.6,
                 zorder=3)[0]
    h2 = ax.plot([med['11-20'][s] for s in order], ypos + 0.13, 'D', ms=ms * 0.9, color=C2C, mec='white',
                 mew=0.6, zorder=3)[0]
    hb = ax.plot([], [], color=BAND, lw=ms * 0.55, solid_capstyle='round')[0]
    ax.set_yticks(ypos)
    ax.set_yticklabels([LABELS[s] for s in order], fontsize=fs * 0.9, color=INK)
    for yy, title in heads:
        ax.text(xl[0] - 0.4, yy - 0.15, title, transform=ax.get_yaxis_transform() if False else ax.transData,
                fontsize=fs * 0.9, fontweight='bold', color=INK, ha='right', va='center', clip_on=False)
    ax.set_ylim(ypos[-1] + 0.8, -0.8)
    ax.set_xlim(*xl)
    tk = list(range(-20, 16, 10 if name == 'paper' else 5))
    ax.set_xticks(tk)
    ax.set_xticklabels([('%+d %%' % v).replace('-', '−') if v else '0' for v in tk], fontsize=fs * 0.9,
                       color=INK2)
    ax.grid(axis='x', color=GRID, lw=0.5, zorder=0)
    for sp in ('top', 'right', 'left'):
        ax.spines[sp].set_visible(False)
    ax.spines['bottom'].set_color(INK2)
    ax.tick_params(axis='y', length=0)
    ax.tick_params(axis='x', colors=INK2)
    ax.set_xlabel('Change of J against C2 (classical controller at the same point)\n'
                  'J = tracking error + base rotation, equally weighted', fontsize=fs, color=INK)
    ax.text(-0.6, -0.75, '← residual RL better', fontsize=fs * 0.85, color=INK2, ha='right', va='bottom',
            style='italic', clip_on=False)
    ax.text(0.6, -0.75, 'C2 better →', fontsize=fs * 0.85, color=INK2, ha='left', va='bottom', style='italic',
            clip_on=False)
    n1 = int((med['1-10'] < 0).sum())
    n2 = int((med['11-20'] < 0).sum())
    leg = ax.legend([h1, h2, hb], ['Seeds 1–10, median (better in %d of 26)' % n1,
                                   'Seeds 11–20, median (better in %d of 26)' % n2,
                                   'Interquartile range, 20 seeds'],
                    loc='upper center', bbox_to_anchor=(0.5, -0.11 if name == 'slide' else -0.12), ncol=1,
                    frameon=False, fontsize=fs * 0.85, labelcolor=INK)
    leg.set_in_layout(True)
    fig.tight_layout()
    for ext in ('pdf', 'png'):
        fig.savefig(os.path.join(FIG, 'robust_res_%s.%s' % (name, ext)), dpi=300, bbox_inches='tight')
    plt.close(fig)
    print(os.path.join(FIG, 'robust_res_%s.{pdf,png}' % name))


def main():
    med, q, sg = load()
    plot(med, q, sg, (3.5, 5.6), 7.5, 4.0, 'paper')
    plot(med, q, sg, (9, 8.6), 14, 8.0, 'slide')


if __name__ == '__main__':
    main()
