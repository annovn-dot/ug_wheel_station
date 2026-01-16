const resourceName = 'ug_wheel_station';

function sendNui(name, data) {
  fetch(`https://${resourceName}/${name}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json; charset=UTF-8' },
    body: JSON.stringify(data || {}),
  }).catch(() => {});
}

window.addEventListener('DOMContentLoaded', () => {
  const overlay     = document.getElementById('overlay');
  const panel       = document.getElementById('panel');
  const tabs        = document.querySelectorAll('#tabs .tab');
  const tabContents = document.querySelectorAll('.tab-content');

  const offsetFL    = document.getElementById('offset-fl');
  const offsetFR    = document.getElementById('offset-fr');
  const offsetRL    = document.getElementById('offset-rl');
  const offsetRR    = document.getElementById('offset-rr');

  const offsetFLVal = document.getElementById('offset-fl-val');
  const offsetFRVal = document.getElementById('offset-fr-val');
  const offsetRLVal = document.getElementById('offset-rl-val');
  const offsetRRVal = document.getElementById('offset-rr-val');

  const width       = document.getElementById('width');
  const widthVal    = document.getElementById('width-val');

  const size        = document.getElementById('size');
  const sizeVal     = document.getElementById('size-val');

  const camberFL    = document.getElementById('camber-fl');
  const camberFR    = document.getElementById('camber-fr');
  const camberRL    = document.getElementById('camber-rl');
  const camberRR    = document.getElementById('camber-rr');

  const camberFLVal = document.getElementById('camber-fl-val');
  const camberFRVal = document.getElementById('camber-fr-val');
  const camberRLVal = document.getElementById('camber-rl-val');
  const camberRRVal = document.getElementById('camber-rr-val');

  const suspension    = document.getElementById('suspension');
  const suspensionVal = document.getElementById('suspension-val');

  const saveBtn   = document.getElementById('save');
  const cancelBtn = document.getElementById('cancel');
  const focusBtn  = document.getElementById('toggle-focus');

  if (!overlay || !panel || !saveBtn || !cancelBtn) {
    console.error('[ug_wheel_station] Missing required DOM elements. Check index.html.');
    return;
  }

  const dirty = {
    offsetFL: false, offsetFR: false, offsetRL: false, offsetRR: false,
    width: false, size: false,
    camberFL: false, camberFR: false, camberRL: false, camberRR: false,
    suspension: false,
  };

  function switchTab(name) {
    tabs.forEach(btn => btn.classList.toggle('active', btn.dataset.tab === name));
    tabContents.forEach(tc => {
      tc.style.display = (tc.getAttribute('data-tab') === name) ? 'block' : 'none';
    });
  }
  tabs.forEach(btn => btn.addEventListener('click', () => switchTab(btn.dataset.tab)));

  let previewTimeout = null;
  function triggerPreview() {
    if (previewTimeout) clearTimeout(previewTimeout);
    previewTimeout = setTimeout(() => sendNui('preview', collectData()), 50);
  }

  function bindRange(input, valueEl, opts) {
    if (!input || !valueEl) return;

    input.min = String(opts.min);
    input.max = String(opts.max);

    input.addEventListener('input', () => {
      dirty[opts.dirtyKey] = true;
      valueEl.textContent = Number(input.value).toFixed(opts.decimals) + (opts.suffix || '');
      triggerPreview();
    });
  }

  bindRange(offsetFL, offsetFLVal, { min: -0.40, max: 0.40, dirtyKey: 'offsetFL', decimals: 2 });
  bindRange(offsetFR, offsetFRVal, { min: -0.40, max: 0.40, dirtyKey: 'offsetFR', decimals: 2 });
  bindRange(offsetRL, offsetRLVal, { min: -0.40, max: 0.40, dirtyKey: 'offsetRL', decimals: 2 });
  bindRange(offsetRR, offsetRRVal, { min: -0.40, max: 0.40, dirtyKey: 'offsetRR', decimals: 2 });

  bindRange(width, widthVal, { min: -0.25, max: 0.25, dirtyKey: 'width', decimals: 2 });
  bindRange(size,  sizeVal,  { min: -0.25, max: 0.25, dirtyKey: 'size',  decimals: 2 });

  bindRange(camberFL, camberFLVal, { min: -12, max: 12, dirtyKey: 'camberFL', decimals: 1, suffix: '°' });
  bindRange(camberFR, camberFRVal, { min: -12, max: 12, dirtyKey: 'camberFR', decimals: 1, suffix: '°' });
  bindRange(camberRL, camberRLVal, { min: -12, max: 12, dirtyKey: 'camberRL', decimals: 1, suffix: '°' });
  bindRange(camberRR, camberRRVal, { min: -12, max: 12, dirtyKey: 'camberRR', decimals: 1, suffix: '°' });

  bindRange(suspension, suspensionVal, { min: -0.20, max: 0.20, dirtyKey: 'suspension', decimals: 2 });

  function resetDirty() {
    Object.keys(dirty).forEach(k => (dirty[k] = false));
  }

  function centerSlider(input, valueEl, decimals, suffix) {
    if (!input || !valueEl) return;
    input.value = 0;
    valueEl.textContent = Number(0).toFixed(decimals) + (suffix || '');
  }

  window.addEventListener('message', (ev) => {
    const d = ev.data;
    if (!d) return;

    if (d.action === 'open') {
      const wheels = (d.data && d.data.wheels) || {};
      window.wheelBase = wheels || {};

      resetDirty();

      centerSlider(offsetFL, offsetFLVal, 2, '');
      centerSlider(offsetFR, offsetFRVal, 2, '');
      centerSlider(offsetRL, offsetRLVal, 2, '');
      centerSlider(offsetRR, offsetRRVal, 2, '');

      centerSlider(width, widthVal, 2, '');
      centerSlider(size,  sizeVal,  2, '');

      centerSlider(camberFL, camberFLVal, 1, '°');
      centerSlider(camberFR, camberFRVal, 1, '°');
      centerSlider(camberRL, camberRLVal, 1, '°');
      centerSlider(camberRR, camberRRVal, 1, '°');

      centerSlider(suspension, suspensionVal, 2, '');

      switchTab('fitment');
      overlay.style.display = 'flex';
    }

    if (d.action === 'close') {
      overlay.style.display = 'none';
    }
  });

  function collectData() {
    const base   = window.wheelBase || {};
    const baseSt = base.stance || {};
    const baseCb = base.camber || {};

    const baseWidth = (typeof base.width === 'number') ? base.width : 0;
    const baseSize  = (typeof base.size === 'number' && Number.isFinite(base.size)) ? base.size : 1.0;

    const baseHeight = (typeof base.height === 'number' && Number.isFinite(base.height)) ? base.height : 0.0;

    const baseFL = (typeof baseSt.fl === 'number') ? baseSt.fl : (typeof baseSt.front === 'number' ? baseSt.front : 0);
    const baseFR = (typeof baseSt.fr === 'number') ? baseSt.fr : (typeof baseSt.front === 'number' ? baseSt.front : 0);
    const baseRL = (typeof baseSt.rl === 'number') ? baseSt.rl : (typeof baseSt.rear  === 'number' ? baseSt.rear  : 0);
    const baseRR = (typeof baseSt.rr === 'number') ? baseSt.rr : (typeof baseSt.rear  === 'number' ? baseSt.rear  : 0);

    const baseCamFLdeg = ((typeof baseCb.fl === 'number') ? baseCb.fl : (typeof baseCb.front === 'number' ? baseCb.front : 0)) * 180 / Math.PI;
    const baseCamFRdeg = ((typeof baseCb.fr === 'number') ? baseCb.fr : (typeof baseCb.front === 'number' ? baseCb.front : 0)) * 180 / Math.PI;
    const baseCamRLdeg = ((typeof baseCb.rl === 'number') ? baseCb.rl : (typeof baseCb.rear  === 'number' ? baseCb.rear  : 0)) * 180 / Math.PI;
    const baseCamRRdeg = ((typeof baseCb.rr === 'number') ? baseCb.rr : (typeof baseCb.rear  === 'number' ? baseCb.rear  : 0)) * 180 / Math.PI;

    const dOffFL = offsetFL ? (parseFloat(offsetFL.value) || 0) : 0;
    const dOffFR = offsetFR ? (parseFloat(offsetFR.value) || 0) : 0;
    const dOffRL = offsetRL ? (parseFloat(offsetRL.value) || 0) : 0;
    const dOffRR = offsetRR ? (parseFloat(offsetRR.value) || 0) : 0;

    const dWidth = width ? (parseFloat(width.value) || 0) : 0;
    const dSize  = size  ? (parseFloat(size.value)  || 0) : 0;

    const dCamFL = camberFL ? (parseFloat(camberFL.value) || 0) : 0;
    const dCamFR = camberFR ? (parseFloat(camberFR.value) || 0) : 0;
    const dCamRL = camberRL ? (parseFloat(camberRL.value) || 0) : 0;
    const dCamRR = camberRR ? (parseFloat(camberRR.value) || 0) : 0;

    const dH = suspension ? (parseFloat(suspension.value) || 0) : 0;

    const finalFL = dirty.offsetFL ? (baseFL + dOffFL) : baseFL;
    const finalFR = dirty.offsetFR ? (baseFR + dOffFR) : baseFR;
    const finalRL = dirty.offsetRL ? (baseRL + dOffRL) : baseRL;
    const finalRR = dirty.offsetRR ? (baseRR + dOffRR) : baseRR;

    let finalWidth = dirty.width ? (baseWidth + dWidth) : baseWidth;
    if (!Number.isFinite(finalWidth) || finalWidth < 0.1) finalWidth = 0.1;

    let finalSize = dirty.size ? (baseSize + dSize) : baseSize;
    if (!Number.isFinite(finalSize)) finalSize = baseSize;
    finalSize = Math.min(1.5, Math.max(0.5, finalSize));

    let finalHeight = dirty.suspension ? (baseHeight + dH) : baseHeight;
    finalHeight = Math.min(0.20, Math.max(-0.20, finalHeight));

    const finalCamFLrad = (dirty.camberFL ? (baseCamFLdeg + dCamFL) : baseCamFLdeg) * Math.PI / 180;
    const finalCamFRrad = (dirty.camberFR ? (baseCamFRdeg + dCamFR) : baseCamFRdeg) * Math.PI / 180;
    const finalCamRLrad = (dirty.camberRL ? (baseCamRLdeg + dCamRL) : baseCamRLdeg) * Math.PI / 180;
    const finalCamRRrad = (dirty.camberRR ? (baseCamRRdeg + dCamRR) : baseCamRRdeg) * Math.PI / 180;

    return {
      stance: {
        front: (finalFL + finalFR) / 2.0,
        rear:  (finalRL + finalRR) / 2.0,
        fl: finalFL, fr: finalFR, rl: finalRL, rr: finalRR,
      },
      camber: {
        front: (finalCamFLrad + finalCamFRrad) / 2.0,
        rear:  (finalCamRLrad + finalCamRRrad) / 2.0,
        fl: finalCamFLrad, fr: finalCamFRrad, rl: finalCamRLrad, rr: finalCamRRrad,
      },
      width: finalWidth,
      size:  finalSize,
      height: finalHeight,
    };
  }

  saveBtn.addEventListener('click', () => sendNui('apply', collectData()));
  cancelBtn.addEventListener('click', () => sendNui('cancel', {}));
  if (focusBtn) focusBtn.addEventListener('click', () => sendNui('toggleFocus', {}));
});
