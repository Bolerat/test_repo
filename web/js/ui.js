// 同窝 Covey · UI 基础组件

export function esc(s) {
  return String(s ?? '')
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');
}

export function icon(name, cls = '') {
  return `<svg class="${cls}" aria-hidden="true"><use href="#${name}"/></svg>`;
}

export function toast(msg) {
  const old = document.querySelector('.toast');
  if (old) old.remove();
  const el = document.createElement('div');
  el.className = 'toast';
  el.textContent = msg;
  document.body.appendChild(el);
  setTimeout(() => el.remove(), 2200);
}

export function openModal(html) {
  closeModal();
  const backdrop = document.createElement('div');
  backdrop.className = 'modal-backdrop';
  backdrop.innerHTML = `<div class="modal" role="dialog" aria-modal="true">${html}</div>`;
  backdrop.addEventListener('click', (e) => {
    if (e.target === backdrop) closeModal();
  });
  document.getElementById('modalRoot').appendChild(backdrop);
  return backdrop.querySelector('.modal');
}

export function closeModal() {
  const root = document.getElementById('modalRoot');
  if (root) root.innerHTML = '';
}

export function openLightbox(src, alt = '') {
  closeModal();
  const el = document.createElement('div');
  el.className = 'lightbox';
  el.innerHTML = `<button class="close-float" type="button" aria-label="关闭">✕</button><img src="${src}" alt="${esc(alt)}">`;
  el.addEventListener('click', (e) => { if (e.target === el || e.target.classList.contains('close-float')) el.remove(); });
  document.body.appendChild(el);
}

export function bindModalEvents(modal, handlers) {
  if (!modal) return;
  modal.addEventListener('click', (e) => {
    const el = e.target.closest('[data-mact]');
    if (!el) return;
    const action = el.dataset.mact;
    const fn = handlers[action];
    if (fn) fn(e, el, modal);
  });
}
