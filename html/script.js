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
  const focusHint = document.getElementById('focus-hint');

  if (!overlay || !panel || !saveBtn || !cancelBtn) {
    console.error('[ug_wheel_station] Missing required DOM elements. Check index.html.');
    return;
  }

  const dirty = {
    offsetFL: false,
    offsetFR: false,
    offsetRL: false,
    offsetRR: false,
    width:    false,
    camberFL: false,
    camberFR: false,
    camberRL: false,
    camberRR: false,
    suspension: false,
  };

  function switchTab(name) {
    tabs.forEach(btn => {
      btn.classList.toggle('active', btn.dataset.tab === name);
    });
    tabContents.forEach(tc => {
      tc.style.display = (tc.getAttribute('data-tab') === name) ? 'block' : 'none';
    });
  }

  tabs.forEach(btn => {
    btn.addEventListener('click', () => switchTab(btn.dataset.tab));
  });

  let previewTimeout = null;
  function triggerPreview() {
    if (previewTimeout) clearTimeout(previewTimeout);
    previewTimeout = setTimeout(() => {
      const payload = collectData();
      sendNui('preview', payload);
    }, 50);
  }

  function bindOffsetSlider(input, valueEl, dirtyKey) {
    if (!input || !valueEl) return;
    input.min = '-0.40';
    input.max =  '0.40';

    input.addEventListener('input', () => {
      dirty[dirtyKey] = true;
      valueEl.textContent = Number(input.value).toFixed(2);
      triggerPreview();
    });
  }

  function bindWidthSlider(input, valueEl) {
    if (!input || !valueEl) return;
    input.min = '-0.25';
    input.max =  '0.25';

    input.addEventListener('input', () => {
      dirty.width = true;
      valueEl.textContent = Number(input.value).toFixed(2);
      triggerPreview();
    });
  }

  function bindCamberSlider(input, valueEl, dirtyKey) {
    if (!input || !valueEl) return;
    input.min = '-12';
    input.max =  '12';

    input.addEventListener('input', () => {
      dirty[dirtyKey] = true;
      valueEl.textContent = Number(input.value).toFixed(1) + '°';
      triggerPreview();
    });
  }

  function bindSuspensionSlider(input, valueEl) {
    if (!input || !valueEl) return;
    input.min = '-0.20';
    input.max =  '0.20';

    input.addEventListener('input', () => {
      dirty.suspension = true;
      valueEl.textContent = Number(input.value).toFixed(2);
      triggerPreview();
    });
  }

  bindOffsetSlider(offsetFL, offsetFLVal, 'offsetFL');
  bindOffsetSlider(offsetFR, offsetFRVal, 'offsetFR');
  bindOffsetSlider(offsetRL, offsetRLVal, 'offsetRL');
  bindOffsetSlider(offsetRR, offsetRRVal, 'offsetRR');

  bindWidthSlider(width, widthVal);

  bindCamberSlider(camberFL, camberFLVal, 'camberFL');
  bindCamberSlider(camberFR, camberFRVal, 'camberFR');
  bindCamberSlider(camberRL, camberRLVal, 'camberRL');
  bindCamberSlider(camberRR, camberRRVal, 'camberRR');

  bindSuspensionSlider(suspension, suspensionVal);

  function resetDirty() {
    for (const k in dirty) dirty[k] = false;
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
    const base    = window.wheelBase || {};
    const baseSt  = base.stance || {};
    const baseCb  = base.camber || {};

    const baseWidth  = (typeof base.width  === 'number') ? base.width  : 0;
    const baseHeight = (typeof base.height === 'number') ? base.height : 0;

    const baseFL = (typeof baseSt.fl === 'number') ? baseSt.fl
                  : (typeof baseSt.front === 'number' ? baseSt.front : 0);
    const baseFR = (typeof baseSt.fr === 'number') ? baseSt.fr
                  : (typeof baseSt.front === 'number' ? baseSt.front : 0);
    const baseRL = (typeof baseSt.rl === 'number') ? baseSt.rl
                  : (typeof baseSt.rear === 'number' ? baseSt.rear : 0);
    const baseRR = (typeof baseSt.rr === 'number') ? baseSt.rr
                  : (typeof baseSt.rear === 'number' ? baseSt.rear : 0);

    const baseCamFLdeg = ((typeof baseCb.fl === 'number') ? baseCb.fl
                         : (typeof baseCb.front === 'number' ? baseCb.front : 0)) * 180 / Math.PI;
    const baseCamFRdeg = ((typeof baseCb.fr === 'number') ? baseCb.fr
                         : (typeof baseCb.front === 'number' ? baseCb.front : 0)) * 180 / Math.PI;
    const baseCamRLdeg = ((typeof baseCb.rl === 'number') ? baseCb.rl
                         : (typeof baseCb.rear === 'number' ? baseCb.rear : 0)) * 180 / Math.PI;
    const baseCamRRdeg = ((typeof baseCb.rr === 'number') ? baseCb.rr
                         : (typeof baseCb.rear === 'number' ? baseCb.rear : 0)) * 180 / Math.PI;

    const dOffFL = offsetFL ? parseFloat(offsetFL.value) || 0 : 0;
    const dOffFR = offsetFR ? parseFloat(offsetFR.value) || 0 : 0;
    const dOffRL = offsetRL ? parseFloat(offsetRL.value) || 0 : 0;
    const dOffRR = offsetRR ? parseFloat(offsetRR.value) || 0 : 0;

    const dWidth = width ? parseFloat(width.value) || 0 : 0;

    const dCamFL = camberFL ? parseFloat(camberFL.value) || 0 : 0;
    const dCamFR = camberFR ? parseFloat(camberFR.value) || 0 : 0;
    const dCamRL = camberRL ? parseFloat(camberRL.value) || 0 : 0;
    const dCamRR = camberRR ? parseFloat(camberRR.value) || 0 : 0;

    const dSusp  = suspension ? parseFloat(suspension.value) || 0 : 0;

    const finalFL = dirty.offsetFL ? (baseFL + dOffFL) : baseFL;
    const finalFR = dirty.offsetFR ? (baseFR + dOffFR) : baseFR;
    const finalRL = dirty.offsetRL ? (baseRL + dOffRL) : baseRL;
    const finalRR = dirty.offsetRR ? (baseRR + dOffRR) : baseRR;

    let finalWidth = baseWidth;
    if (dirty.width) {
      finalWidth = baseWidth + dWidth;
    }
    if (!Number.isFinite(finalWidth) || finalWidth < 0.1) {
      finalWidth = 0.1;
    }

    let finalHeight = baseHeight;
    if (dirty.suspension) {
      finalHeight = baseHeight + dSusp;
    }

    const finalCamFLdeg = dirty.camberFL ? (baseCamFLdeg + dCamFL) : baseCamFLdeg;
    const finalCamFRdeg = dirty.camberFR ? (baseCamFRdeg + dCamFR) : baseCamFRdeg;
    const finalCamRLdeg = dirty.camberRL ? (baseCamRLdeg + dCamRL) : baseCamRLdeg;
    const finalCamRRdeg = dirty.camberRR ? (baseCamRRdeg + dCamRR) : baseCamRRdeg;

    const finalCamFLrad = finalCamFLdeg * Math.PI / 180;
    const finalCamFRrad = finalCamFRdeg * Math.PI / 180;
    const finalCamRLrad = finalCamRLdeg * Math.PI / 180;
    const finalCamRRrad = finalCamRRdeg * Math.PI / 180;

    return {
      stance: {
        front: (finalFL + finalFR) / 2.0,
        rear:  (finalRL + finalRR) / 2.0,
        fl: finalFL,
        fr: finalFR,
        rl: finalRL,
        rr: finalRR,
      },
      camber: {
        front: (finalCamFLrad + finalCamFRrad) / 2.0,
        rear:  (finalCamRLrad + finalCamRRrad) / 2.0,
        fl: finalCamFLrad,
        fr: finalCamFRrad,
        rl: finalCamRLrad,
        rr: finalCamRRrad,
      },
      width:  finalWidth,
      height: finalHeight,
    };
  }

  saveBtn.addEventListener('click', () => {
    const payload = collectData();
    sendNui('apply', payload);
  });

  cancelBtn.addEventListener('click', () => {
    sendNui('cancel', {});
  });

  if (focusBtn) {
    focusBtn.addEventListener('click', () => {
      sendNui('toggleFocus', {});
    });
  }

  window.collectWheelData = collectData;
});
