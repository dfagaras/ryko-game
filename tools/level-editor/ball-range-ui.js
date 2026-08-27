(() => {
  "use strict";

  const M = window.RykoLevelModel;
  const select = document.getElementById("ballSizeSelect");
  const readout = document.getElementById("ballSizeReadout");
  if (!M || !select) return;

  const options = [
    [0.20, "0.20× — experimental tiny"],
    [0.35, "0.35× — experimental tiny"],
    [0.50, "0.50× — very small"],
    [0.70, "0.70× — small"],
    [0.85, "0.85× — slightly small"],
    [1.00, "1.00× — standard"],
    [1.15, "1.15× — slightly large"],
    [1.30, "1.30× — large"],
    [1.50, "1.50× — experimental large"],
    [2.00, "2.00× — experimental huge"],
    [2.50, "2.50× — experimental huge"],
    [3.00, "3.00× — experimental maximum"]
  ];

  const current = M.normalizeBallSizeMultiplier(JSON.parse(localStorage.getItem("ryko-level-editor-v1") || "null")?.ball?.sizeMultiplier ?? 1);
  select.innerHTML = "";
  for (const [value, label] of options) {
    const option = document.createElement("option");
    option.value = value.toFixed(2);
    option.textContent = label;
    select.appendChild(option);
  }
  select.value = current.toFixed(2);

  const updateWarning = () => {
    const value = Number(select.value || 1);
    let warning = "Recommended range: 0.65×–1.35×.";
    if (value < 0.65) warning += " Tiny ball mode: verify phone visibility and narrow collision paths.";
    if (value > 1.35) warning += " Large ball mode: verify corridor fit and collision feel.";
    if (readout) {
      const existing = readout.textContent.split(" · Recommended range:")[0];
      readout.textContent = `${existing} · ${warning}`;
    }
  };

  select.addEventListener("change", () => setTimeout(updateWarning, 0));
  setTimeout(updateWarning, 0);
})();
