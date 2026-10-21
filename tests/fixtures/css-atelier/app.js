"use strict";

(async () => {
  const get = (id) => document.getElementById(id);
  const blue = "#4164c8";
  const coral = "#dc654c";
  const supports = (property, value) => Boolean(window.CSS && CSS.supports(property, value));
  const selector = (value) => Boolean(window.CSS && CSS.supports(`selector(${value})`));
  const pressed = (button, active) => button.setAttribute("aria-pressed", String(active));
  // Initialize the chapters in separate browser tasks so a long reference
  // page gives rendering and input a chance to run between setup phases.
  const nextTask = () => new Promise((resolve) => setTimeout(resolve, 0));
  const mark = (element, available, label) => {
    element.textContent = label || (available ? "Syntax verfügbar" : "Hier nicht verfügbar");
    element.classList.toggle("available", available);
    element.classList.toggle("unavailable", !available);
  };

  const layerSupport = () => {
    const probe = document.createElement("style");
    probe.textContent = "@layer atelier_probe { .atelier_unused_probe { color: red; } }";
    document.head.append(probe);
    const rule = probe.sheet && probe.sheet.cssRules[0];
    const found = Boolean(rule && rule.cssText.startsWith("@layer") && "cssRules" in rule);
    probe.remove();
    return found;
  };
  const typed = Boolean(window.CSS && typeof CSS.px === "function" && get("cssom-tile").attributeStyleMap && typeof get("cssom-tile").computedStyleMap === "function");
  const features = {
    layers: layerSupport,
    variables: () => supports("color", "var(--farbe)"),
    selectors: () => selector(":has(input:checked)") && selector(":nth-child(2n of .picked)"),
    shadow: () => Boolean(window.customElements && Element.prototype.attachShadow),
    container: () => supports("container-type", "inline-size") && supports("width", "1cqw"),
    "media-range": () => matchMedia("(0px <= width)").matches,
    "text-box": () => supports("text-box-trim", "trim-both") && supports("text-box-edge", "cap alphabetic"),
    subgrid: () => supports("grid-template-rows", "subgrid"),
    colors: () => ["srgb", "oklab", "oklch"].every((space) => supports("color", `color-mix(in ${space}, coral 50%, royalblue)`)),
    "image-set": () => supports("background-image", 'image-set(url("density-1.svg") 1x, url("density-2.svg") 2x)'),
    "scroll-timeline": () => supports("animation-timeline", "scroll()") && supports("animation-timeline", "view()") && supports("animation-range", "entry 0% cover 35%"),
    anchor: () => "showPopover" in HTMLElement.prototype && supports("position-anchor", "--menu-button") && supports("top", "anchor(bottom)") && supports("position-try-fallbacks", "flip-block, flip-inline, flip-block flip-inline"),
    "interpolate-size": () => supports("interpolate-size", "allow-keywords"),
    composition: () => ["replace", "add", "accumulate"].every((value) => supports("animation-composition", value)),
    waapi: () => typeof Element.prototype.animate === "function",
    "typed-om": () => typed,
    "view-transition": () => typeof document.startViewTransition === "function",
    highlight: () => Boolean(window.CSS && CSS.highlights && window.Highlight),
    "paint-worklet": () => Boolean(window.CSS && CSS.paintWorklet && typeof CSS.paintWorklet.addModule === "function")
  };
  const available = {};
  document.querySelectorAll("[data-feature]").forEach((badge) => {
    const name = badge.dataset.feature;
    try { available[name] = Boolean(features[name]()); }
    catch { available[name] = false; }
    const api = ["shadow", "waapi", "typed-om", "view-transition", "highlight", "paint-worklet"].includes(name);
    mark(badge, available[name], available[name] ? (api ? "API verfügbar" : "Syntax verfügbar") : "Hier nicht verfügbar");
  });

  // 01: Eigenschaften ändern; die Kaskade selbst löst weiterhin der Browser auf.
  get("layer-toggle").addEventListener("click", () => {
    const active = get("layer-panel").classList.toggle("zurueck");
    pressed(get("layer-toggle"), active);
    get("layer-sample").firstElementChild.textContent = active ? "Die korallene Basis kommt zurück" : "Die spätere Theme-Ebene gewinnt";
    get("layer-toggle").textContent = active ? "Theme-Farbe wieder anwenden" : "Oberste Farbe mit revert-layer zurücknehmen";
  });
  get("layer-toggle").disabled = !available.layers;
  get("valid-variable").addEventListener("change", (event) => {
    get("var-panel").style.setProperty("--farbe", event.target.checked ? coral : "18px");
    get("var-panel").querySelector(".var-sample").textContent = event.target.checked ? "Die Variable ist gültiges Korall." : "Ich erbe das Blau.";
  });
  const updateWideValue = () => {
    const value = get("wide-keyword").value;
    if (value) get("keyword-sample").style.color = value;
    else get("keyword-sample").style.removeProperty("color");
    get("wide-result").textContent = `Berechnete Farbe: ${getComputedStyle(get("keyword-sample")).color}`;
  };
  get("wide-keyword").addEventListener("change", updateWideValue);
  updateWideValue();

  // 02: Das eigene Element gibt nur eine Oberfläche durch ::part frei.
  await nextTask();
  if (available.shadow) {
    customElements.define("atelier-chip", class extends HTMLElement {
      constructor() {
        super();
        this.attachShadow({ mode: "open" }).innerHTML = `<style>
          :host { display: block; }
          .surface { border: 2px solid #bac6d6; background: white; padding: 25px; }
          small { display: block; color: #627180; margin-bottom: 10px; font: 11px "Segoe UI", sans-serif; }
          strong { display: block; font: 26px Georgia, serif; margin-bottom: 12px; color: #223447; }
          ::slotted(span) { color: #4164c8; font: 15px "Segoe UI", sans-serif; }
        </style><div class="surface" part="surface"><small>INNERHALB DES SHADOW-BAUMS</small><strong>Ein eigener kleiner Raum.</strong><slot></slot></div>`;
      }
    });
  }
  get("shadow-toggle").disabled = !available.shadow;
  get("shadow-toggle").addEventListener("click", () => {
    pressed(get("shadow-toggle"), document.querySelector(".shadow-stage").classList.toggle("alternate"));
  });

  // 03: Gemessene Containerbreite und tatsächlich erkannte Systempräferenzen.
  await nextTask();
  const container = get("container-shell");
  const containerSize = () => {
    get("container-size").textContent = `${Math.round(container.getBoundingClientRect().width)} px`;
  };
  get("container-width").addEventListener("input", (event) => {
    container.style.width = `${event.target.value}px`;
    containerSize();
  });
  containerSize();
  const queries = [
    [matchMedia("(prefers-reduced-motion: reduce)"), "motion-readout"],
    [matchMedia("(hover: hover)"), "hover-readout"],
    [matchMedia("(forced-colors: active)"), "contrast-readout"]
  ];
  queries.forEach(([query, id]) => {
    const update = () => { get(id).textContent = query.matches ? "Ja" : "Nein"; };
    update();
    query.addEventListener("change", update);
  });
  const viewportInfo = () => {
    get("viewport-readout").textContent = `${window.innerWidth} CSS-px`;
    get("density-readout").textContent = `Aktuelle Pixeldichte: ${window.devicePixelRatio.toFixed(2)} Gerätepixel je CSS-Pixel`;
  };
  viewportInfo();

  // 04: Achsenwerte betreffen eine Fontdatei, keine transform-Skalierung.
  await nextTask();
  get("writing-mode").addEventListener("change", (event) => {
    get("writing-sample").style.writingMode = event.target.value;
  });
  const updateFont = () => {
    const weight = Number(get("font-weight").value);
    const width = Number(get("font-width").value);
    get("variable-sample").style.fontVariationSettings = `"wght" ${weight}, "wdth" ${width}`;
    get("weight-value").textContent = String(weight);
    get("width-value").textContent = `${width} %`;
  };
  get("font-weight").addEventListener("input", updateFont);
  get("font-width").addEventListener("input", updateFont);
  updateFont();
  document.fonts.load('48px "Atelier Variable"', "Aa Formgefühl").then((faces) => {
    const loaded = faces.some((face) => face.status === "loaded");
    mark(get("font-support"), loaded, loaded ? "Variable Schrift geladen" : "Schrift nicht verfügbar");
    if (!loaded) { get("font-weight").disabled = true; get("font-width").disabled = true; }
  }).catch(() => {
    mark(get("font-support"), false, "Schrift konnte nicht laden");
    get("font-weight").disabled = true;
    get("font-width").disabled = true;
  });

  // 05–07: Die eigentliche Berechnung, Quellenwahl und Darstellung bleibt CSS.
  await nextTask();
  get("align-items").addEventListener("change", (event) => {
    get("baseline-stage").style.alignItems = event.target.value;
  });
  get("clip-check").addEventListener("change", (event) => {
    get("effect-image").classList.toggle("is-clipped", event.target.checked);
  });
  get("mask-check").addEventListener("change", (event) => {
    get("effect-image").classList.toggle("is-masked", event.target.checked);
  });
  get("blur-range").addEventListener("input", (event) => {
    get("effect-image").style.filter = `blur(${event.target.value}px)`;
    get("blur-value").textContent = `${event.target.value} px`;
  });
  get("blend-mode").addEventListener("change", (event) => {
    get("blend-stage").lastElementChild.style.mixBlendMode = event.target.value;
  });
  get("flip-card").addEventListener("click", () => {
    pressed(get("flip-card"), get("flip-card").classList.toggle("is-flipped"));
  });
  get("scheme-toggle").addEventListener("click", () => {
    const active = get("native-panel").classList.toggle("dark-scheme");
    pressed(get("scheme-toggle"), active);
    get("scheme-toggle").textContent = active ? "Helle Controldarstellung" : "Dunkle Controldarstellung";
  });
  if (!("showPopover" in HTMLElement.prototype)) {
    get("anchor-trigger").disabled = true;
    get("anchor-menu").hidden = true;
  }
  get("zoom-range").addEventListener("input", (event) => {
    get("zoom-sample").style.zoom = `${event.target.value}%`;
    get("zoom-value").textContent = `${event.target.value} %`;
  });

  // 08: Eine pausierte WAAPI-Animation; kein dauernder requestAnimationFrame-Loop.
  await nextTask();
  const motionTracks = [...document.querySelectorAll(".motion-track")];
  const measureTracks = () => {
    motionTracks.forEach((track) => {
      track.style.setProperty("--travel", `${Math.max(0, track.clientWidth - track.firstElementChild.offsetWidth)}px`);
    });
  };
  measureTracks();
  get("easing-toggle").addEventListener("click", () => {
    const moved = get("easing-demo").classList.toggle("is-moved");
    pressed(get("easing-toggle"), moved);
    get("easing-toggle").textContent = moved ? "Bewegung zurück" : "Bewegung starten";
  });
  get("height-toggle").addEventListener("click", () => {
    const open = get("auto-panel").classList.toggle("is-open");
    get("height-toggle").setAttribute("aria-expanded", String(open));
    get("height-toggle").textContent = open ? "Inhalt zuklappen" : "Inhalt aufklappen";
  });
  get("composition-start").disabled = !available.composition;
  get("composition-start").addEventListener("click", () => {
    const demo = get("composition-demo");
    demo.classList.remove("is-running");
    void demo.offsetWidth; // Einmaliger Flush für einen ausdrücklich gewünschten Neustart.
    demo.classList.add("is-running");
  });
  const scrubTrack = get("scrub-object").parentElement;
  let scrub = null;
  const scrubFrames = () => {
    const travel = Math.max(0, scrubTrack.clientWidth - 24 - get("scrub-object").offsetWidth);
    return [{ transform: "translateX(0) rotate(0deg)" }, { transform: `translateX(${travel}px) rotate(180deg)` }];
  };
  if (available.waapi) {
    scrub = get("scrub-object").animate(scrubFrames(), { duration: 1500, fill: "both", easing: "ease-in-out" });
    scrub.pause();
    scrub.currentTime = 0;
  } else {
    get("time-range").disabled = true;
  }
  get("time-range").addEventListener("input", (event) => {
    const time = Number(event.target.value) * 15;
    if (scrub) scrub.currentTime = time;
    get("time-value").textContent = `${time.toLocaleString("de-DE")} ms`;
  });
  const measureScrub = () => {
    if (scrub) scrub.effect.setKeyframes(scrubFrames());
  };
  if (window.ResizeObserver) {
    const sizes = new ResizeObserver((entries) => {
      if (entries.some((entry) => entry.target === container)) containerSize();
      if (entries.some((entry) => motionTracks.includes(entry.target))) measureTracks();
      if (entries.some((entry) => entry.target === scrubTrack)) measureScrub();
    });
    [container, ...motionTracks, scrubTrack].forEach((element) => sizes.observe(element));
  }
  let resizePending = false;
  window.addEventListener("resize", () => {
    if (resizePending) return;
    resizePending = true;
    requestAnimationFrame(() => {
      resizePending = false;
      viewportInfo();
      if (!window.ResizeObserver) { containerSize(); measureTracks(); measureScrub(); }
    });
  });

  // 09: CSSOM-Regel, Typed-OM-Wert, native Snapshots, Range und Paint-Modul.
  await nextTask();
  const liveStyle = document.createElement("style");
  liveStyle.textContent = `#cssom-tile { background: ${blue}; }`;
  document.head.append(liveStyle);
  const liveRule = liveStyle.sheet.cssRules[0];
  get("cssom-toggle").addEventListener("click", () => {
    const active = get("cssom-toggle").getAttribute("aria-pressed") !== "true";
    liveRule.style.backgroundColor = active ? coral : blue;
    pressed(get("cssom-toggle"), active);
  });
  const updateTyped = () => {
    const value = Number(get("typed-width").value);
    if (typed) {
      get("cssom-tile").attributeStyleMap.set("width", CSS.px(value));
      get("typed-value").textContent = `${get("cssom-tile").computedStyleMap().get("width")} · Typed OM`;
    } else {
      get("cssom-tile").style.width = `${value}px`;
      get("typed-value").textContent = `${value} px · CSSOM`;
    }
  };
  get("typed-width").addEventListener("input", updateTyped);
  updateTyped();
  get("view-toggle").addEventListener("click", async () => {
    const button = get("view-toggle");
    button.disabled = true;
    const change = () => {
      const evening = get("transition-scene").classList.toggle("is-evening");
      get("transition-photo").src = evening ? "evening.svg" : "morning.svg";
      get("transition-photo").alt = evening ? "Eine dunkle Berglandschaft unter dem Mond" : "Eine helle Berglandschaft";
      get("transition-time").textContent = evening ? "Abends" : "Morgens";
      get("transition-title").textContent = evening ? "Eine andere Stimmung." : "Ein neuer Blick.";
      button.textContent = evening ? "Zur Morgenansicht wechseln" : "Zur Abendansicht wechseln";
    };
    try {
      if (available["view-transition"]) {
        const transition = document.startViewTransition(async () => {
          change();
          await get("transition-photo").decode().catch(() => {});
        });
        await transition.finished;
      } else change();
    } catch {
      // Ein unterbrochener Snapshot hebt die bereits ausgeführte DOM-Änderung nicht auf.
    } finally { button.disabled = false; }
  });
  get("highlight-toggle").disabled = !available.highlight;
  get("highlight-toggle").addEventListener("click", () => {
    const button = get("highlight-toggle");
    const active = button.getAttribute("aria-pressed") !== "true";
    if (active) {
      const text = get("highlight-text").firstChild;
      const start = text.textContent.indexOf("Auswahl");
      const range = new Range();
      range.setStart(text, start);
      range.setEnd(text, start + "Auswahl".length);
      CSS.highlights.set("atelier-selection", new Highlight(range));
    } else CSS.highlights.delete("atelier-selection");
    pressed(button, active);
  });
  get("paint-start").disabled = !available["paint-worklet"];
  if (!available["paint-worklet"]) get("paint-result").textContent = "Diese Umgebung bietet die Paint-API hier nicht an. Die Fläche bleibt unverändert.";
  let paintModule = null;
  get("paint-start").addEventListener("click", async () => {
    const button = get("paint-start");
    button.disabled = true;
    get("paint-result").textContent = "Paint-Modul wird geladen …";
    try {
      if (!paintModule) paintModule = CSS.paintWorklet.addModule("paint.js");
      await paintModule;
      get("paint-stage").classList.add("paint-ready");
      get("paint-result").textContent = "Das Raster wird jetzt vom echten Paint Worklet gezeichnet.";
      button.textContent = "Paint Worklet aktiv";
    } catch {
      paintModule = null;
      button.disabled = false;
      get("paint-result").textContent = "Das Paint-Modul konnte nicht geladen werden. Die Fläche bleibt neutral; du kannst erneut versuchen.";
    }
  });

  // Das Linkziel gehört zur Adresse, nicht zu einer nachgebauten Scroll-Erkennung.
  await nextTask();
  const chapterLinks = [...document.querySelectorAll(".chapter-nav a")];
  const updateChapter = () => {
    chapterLinks.forEach((link) => {
      if (link.hash === location.hash) link.setAttribute("aria-current", "location");
      else link.removeAttribute("aria-current");
    });
  };
  window.addEventListener("hashchange", updateChapter);
  updateChapter();
})();
