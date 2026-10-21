"use strict";

registerPaint("atelier-grid", class {
  static get inputProperties() { return ["--grid-step"]; }

  paint(context, size, properties) {
    const parsed = Number(properties.get("--grid-step").toString());
    const step = Number.isFinite(parsed) ? Math.max(12, Math.min(80, parsed)) : 26;
    context.fillStyle = "#edf0f5";
    context.fillRect(0, 0, size.width, size.height);
    context.strokeStyle = "#c5cedb";
    context.lineWidth = 1;
    context.beginPath();
    for (let x = .5; x < size.width; x += step) {
      context.moveTo(x, 0);
      context.lineTo(x, size.height);
    }
    for (let y = .5; y < size.height; y += step) {
      context.moveTo(0, y);
      context.lineTo(size.width, y);
    }
    context.stroke();
    context.fillStyle = "#dc654c";
    for (let x = step / 2; x < size.width; x += step * 3) {
      for (let y = step / 2; y < size.height; y += step * 3) {
        context.beginPath();
        context.arc(x, y, 3, 0, Math.PI * 2);
        context.fill();
      }
    }
  }
});
