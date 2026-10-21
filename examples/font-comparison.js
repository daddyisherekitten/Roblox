'use strict';

const fontName = document.body.dataset.fontLabel;
const webFont = document.body.dataset.webFont;
const sizes = document.body.dataset.sizes
  ? document.body.dataset.sizes.split(',').map(Number)
  : [10, 20, 30, 40, 50, 60, 70, 80];
if (webFont) {
  document.fonts.load(`20px "${webFont}"`, 'H x p').then(faces => {
    if (!faces.length) throw new Error('Font fehlt');
    document.body.classList.remove('font-pending');
    const factor = document.body.dataset.testFactor;
    document.getElementById('font-status').textContent = `${fontName} geladen. ` + (factor
      ? `Roblox-Testfaktor ${factor}; H-Höhe erneut prüfen.`
      : 'Roblox: neutraler Testfaktor 1,00; eigener Fontfaktor noch unbekannt. Jetzt H-Höhen vergleichen.');
  }).catch(() => {
    document.body.classList.add('font-failed');
    document.getElementById('font-status').textContent = 'Font konnte nicht geladen werden. Bei lokalen Schriften den Ordner fonts prüfen, bei Google Fonts die Internetverbindung. Noch nicht vergleichen.';
  });
}

const reports = new Map();
const container = document.getElementById('samples');
const results = document.getElementById('results');
const names = ['Oben · H', 'x-Oberkante', 'Basis · H unten', 'Unten · p'];
const colors = ['#f28199', '#77dfab', '#ffc054', '#c09dff'];
for (const size of sizes) {
  const row = document.createElement('section');
  row.className = 'row';
  row.innerHTML = `<div class="title"></div>
    <div class="sample" style="font-size:${size}px"></div>
    <div class="ruler"></div><div class="ruler-label">← 100 px Referenz (keine Schriftmessung)</div>
    <div class="report"></div><div class="note">Chrome · manuelle Linien · noch keine bestätigte Messung</div>`;
  row.querySelector('.title').textContent = `${fontName} | ${size} px`;
  const sample = row.querySelector('.sample');
  sample.textContent = 'H x p';
  if (webFont) sample.style.fontFamily = `"${webFont}"`;
  container.append(row);
  const reportLabel = row.querySelector('.report');
  const offsets = [0, Math.floor(size / 3), Math.round(size), Math.round(size) + 4];
  function report() {
    const value = `${size} px: Oben=${offsets[0]} | x=${offsets[1]} | Basis=${offsets[2]} | Unten=${offsets[3]} | H-Abstand=${offsets[2] - offsets[0]}`;
    reportLabel.textContent = value;
    reports.set(size, value);
    results.value = `Chrome / ${fontName} / manuelle Werte\n` + [...reports.values()].join('\n');
  }
  names.forEach((name, i) => {
    const guide = document.createElement('div');
    guide.className = 'guide';
    guide.style.background = colors[i];
    row.append(guide);
    const control = document.createElement('div');
    control.className = 'control';
    control.style.top = `${38 + i * 35}px`;
    const caption = document.createElement('span');
    caption.className = 'caption';
    caption.style.color = colors[i];
    control.append(caption);
    const update = () => {
      guide.style.top = `${44 + offsets[i]}px`;
      caption.textContent = `${name}: ${offsets[i]} px`;
    };
    for (const delta of [-1, 1]) {
      const button = document.createElement('button');
      button.type = 'button';
      button.textContent = delta < 0 ? '−1' : '+1';
      button.setAttribute('aria-label', `${fontName}, ${size} px: ${name} ${delta < 0 ? 'hoch' : 'runter'}`);
      button.addEventListener('click', () => {
        const next = Math.max(0, Math.min(100, offsets[i] + delta));
        if (next === offsets[i]) return;
        offsets[i] = next;
        update();
        report();
      });
      control.append(button);
    }
    row.append(control);
    update();
  });
  report();
}
document.getElementById('visibility').addEventListener('click', event => {
  const hidden = container.classList.toggle('hide-guides');
  event.currentTarget.textContent = hidden ? 'Hilfslinien einblenden' : 'Hilfslinien ausblenden';
  event.currentTarget.setAttribute('aria-pressed', String(hidden));
});

