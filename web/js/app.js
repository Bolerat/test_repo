// 同窝 Covey · 应用入口与页面渲染
import {
  loadState, saveState, defaultState, resetState, defaultTasks,
  TASK_TYPES, ENTRY_TYPES, REMINDER_CATEGORIES, AI_PROVIDERS, SPECIES,
  todayKey, dateKeyOf, fmtDateCN, fmtFullDate, timeKeyOf,
  uid, memberName, avatarColor,
  isTaskDone, completeTask, undoTask, careProgress, todayCompletions,
  careStreak, weekStats, remindersDueSoon,
  lastWeight, daysSinceWeight, exportJSON,
} from './store.js';
import { testConnection, chatOnce, buildSystemPrompt } from './ai.js';
import { esc, icon, toast, openModal, closeModal, openLightbox, bindModalEvents } from './ui.js';

let state = loadState();
let route = 'today';
let pendingAiPrompt = null;
let journalFilter = 'all';
let journalQuery = '';
let chatBusy = false;

const $view = document.getElementById('view');
const petChip = document.getElementById('petChip');

function persist() { saveState(state); }
function refresh() { render(); updatePetChip(); }
function navigate(r) { if (location.hash !== '#/' + r) location.hash = '#/' + r; else render(); }

/* ================= 通用小组件 ================= */

function tagHTML(type) {
  const t = ENTRY_TYPES[type] || ENTRY_TYPES.note;
  const cls = t.tagClass === 'care' ? 'care' : t.tagClass;
  return `<span class="tag ${cls}">${t.label}</span>`;
}

function entryIconHTML(type) {
  const t = ENTRY_TYPES[type] || ENTRY_TYPES.note;
  return icon(t.icon);
}

function emptyHTML(text) {
  return `<div class="empty">${icon('i-paw')}<p>${esc(text)}</p></div>`;
}

/* ================= 今日 ================= */

function renderToday() {
  const pet = state.pet;
  const now = new Date();
  const dateCN = `${now.getMonth() + 1}月${now.getDate()}日 ${['周日', '周一', '周二', '周三', '周四', '周五', '周六'][now.getDay()]}`;
  const { done, total } = careProgress(state);
  const streak = careStreak(state);
  const week = weekStats(state);
  const reminders = remindersDueSoon(state, 7);
  const lastW = lastWeight(state);

  const allDone = total > 0 && done === total;
  const heroCirc = 2 * Math.PI * 42;
  const heroOffset = heroCirc * (1 - (total ? done / total : 0));
  const speciesInfo = SPECIES[pet.species] || SPECIES.other;
  const age = pet.birthday ? ageText(pet.birthday) : '';
  const petTags = [speciesInfo.label, pet.breed, age].filter(Boolean);
  const heroWeight = lastW ? lastW.kg : pet.weight;

  const taskRows = state.tasks.map((t) => {
    const finished = isTaskDone(state, t.id);
    const comp = todayCompletions(state)[t.id];
    const typeInfo = TASK_TYPES[t.type] || {};
    const timeLabel = comp ? `${timeKeyOf(new Date(comp.at))} 完成` : t.time;
    return `<li class="task ${finished ? 'done' : ''}">
      <button class="check" type="button" data-action="toggle-task" data-id="${t.id}" aria-pressed="${finished}" aria-label="${finished ? '撤销' : '完成'}：${esc(t.title)}">${icon('i-check')}</button>
      <div class="task-main">
        <div class="task-title">${esc(t.title)}</div>
        <div class="task-meta"><span class="tag ${typeInfo.tagClass || ''}">${typeInfo.label || ''}</span><span>${timeLabel}</span>${comp ? `<span>· ${esc(memberName(state, comp.by))}</span>` : ''}</div>
      </div>
    </li>`;
  }).join('');

  const reminderRows = reminders.slice(0, 3).map((r) => {
    const cat = REMINDER_CATEGORIES[r.category] || '提醒';
    const dueText = r.overdue ? '已过期' : r.due === todayKey() ? '今天' : `${r.due.slice(5).replace('-', '月')}日`;
    return `<div class="reminder-item ${r.overdue ? 'overdue' : ''}">
      <div class="rem-main">
        <div class="rem-title">${esc(r.title)}</div>
        <div class="rem-sub">${cat}${r.note ? ' · ' + esc(r.note) : ''}</div>
      </div>
      <span class="rem-due">${dueText}</span>
      <button class="icon-btn" type="button" data-action="reminder-done" data-id="${r.id}" aria-label="标记完成" title="标记完成">${icon('i-check')}</button>
      <button class="icon-btn" type="button" data-action="reminder-del" data-id="${r.id}" aria-label="删除">${icon('i-trash')}</button>
    </div>`;
  }).join('');

  const recentEntries = state.entries.slice(0, 3).map((e) => entryCardHTML(e)).join('');

  return `
    <section>
      <div class="pet-hero">
        <div class="pet-hero-top">
          <div class="pet-avatar ${allDone ? 'all-done' : ''}">
            <svg class="pet-ring" viewBox="0 0 92 92">
              <circle class="bg-ring" cx="46" cy="46" r="42"></circle>
              <circle class="fg-ring" cx="46" cy="46" r="42" stroke-dasharray="${heroCirc.toFixed(1)}" stroke-dashoffset="${heroOffset.toFixed(1)}"></circle>
            </svg>
            <div class="pet-face">${icon(speciesInfo.icon)}</div>
            <span class="pet-badge">${icon(allDone ? 'i-check' : 'i-paw')}${done}/${total}</span>
          </div>
          <div class="pet-id">
            <h1>${esc(pet.name)}</h1>
            <div class="pet-tags">${petTags.map((t) => `<span>${esc(t)}</span>`).join('')}</div>
            <p class="pet-date">${icon('i-cal')}${dateCN}</p>
          </div>
        </div>
        <div class="pet-stats">
          <div class="pet-stat"><div class="v"><i class="accent">${icon('i-heart')}</i>${streak}<small>天</small></div><div class="l">连续照顾</div></div>
          <div class="pet-stat"><div class="v"><i class="sage">${icon('i-chart')}</i>${week.rate}<small>%</small></div><div class="l">近 7 天完成</div></div>
          <div class="pet-stat"><div class="v"><i class="blue">${icon('i-health')}</i>${heroWeight ? `${heroWeight}<small>kg</small>` : '—'}</div><div class="l">体重</div></div>
        </div>
      </div>

      <div class="quick-row">
        <button class="quick-btn" type="button" data-action="quick-photo">${icon('i-camera')}<span>拍一张</span></button>
        <button class="quick-btn" type="button" data-action="quick-note">${icon('i-note')}<span>记一笔</span></button>
        <button class="quick-btn" type="button" data-action="ask-ai-today">${icon('i-wand')}<span>AI 建议</span></button>
      </div>

      <div class="card">
        <div class="card-head"><h2>今日照护</h2><span class="care-count">${done}/${total}</span></div>
        <div class="care-bar"><span style="width:${total ? (done / total) * 100 : 0}%"></span></div>
        <ul class="task-list">${taskRows}</ul>
      </div>

      <div class="card">
        <div class="card-head">
          <h2>照护提醒</h2>
          <button class="more" type="button" data-action="open-reminder-form">+ 新建</button>
        </div>
        ${reminderRows || emptyHTML('近期没有待办提醒，疫苗、驱虫、洗护都可以记在这里')}
      </div>

      <div class="card">
        <div class="card-head">
          <h2>Pawly 的观察</h2>
          <button class="more" type="button" data-action="ask-ai-today">${icon('i-wand')} 让 AI 分析</button>
        </div>
        <p class="muted" style="margin:0 0 8px">${ruleInsight(state)}</p>
      </div>

      <div class="section-head"><h2>最新记录</h2><button class="more" type="button" data-action="nav" data-route="journal">查看全部</button></div>
      ${recentEntries || emptyHTML('还没有记录，完成照护或记一笔后会出现在这里')}
    </section>`;
}

function ruleInsight(state) {
  const week = weekStats(state);
  const due = remindersDueSoon(state, 7).length;
  const daysW = daysSinceWeight(state);
  const parts = [];
  if (week.rate >= 80) parts.push(`这周照护完成率 ${week.rate}%，状态不错。`);
  else if (week.total > 0) parts.push(`这周照护完成率 ${week.rate}%，可以留意漏掉的环节。`);
  if (due > 0) parts.push(`${due} 件提醒在 7 天内到期。`);
  if (daysW != null && daysW > 30) parts.push(`体重已经 ${daysW} 天没记录了。`);
  if (!parts.length) parts.push('记录越多，我越能给出有依据的建议。先完成今天的照护吧。');
  return parts.join('');
}

function entryCardHTML(e) {
  const time = new Date(e.ts);
  const p = (n) => String(n).padStart(2, '0');
  const timeLabel = `${p(time.getMonth() + 1)}-${p(time.getDate())} ${p(time.getHours())}:${p(time.getMinutes())}`;
  const amount = e.amount != null ? `<span class="amount">¥${Number(e.amount).toFixed(2)}</span>` : '';
  const photo = e.photo ? `<img class="entry-photo" src="${e.photo}" alt="照片" loading="lazy" data-action="view-photo" data-src="${e.photo}">` : '';
  return `<button class="entry" type="button" data-action="open-entry" data-id="${e.id}" style="border-left-color: var(--${entryAccent(e.type)});"><div class="entry-icon">${entryIconHTML(e.type)}</div>
    <div class="entry-body">
      <div style="display:flex;gap:6px;align-items:center;flex-wrap:wrap">${tagHTML(e.type)} ${amount}</div>
      ${e.text ? `<div class="entry-text">${esc(e.text)}</div>` : ''}
      ${photo}
      <div class="entry-meta"><span>${timeLabel}</span><span>· ${esc(memberName(state, e.by))}</span></div>
    </div></button>`;
}

function entryAccent(type) {
  return { care: 'gold', note: 'sage', photo: 'blue', spend: 'accent', health: 'danger' }[type] || 'line';
}

/* ================= 记录 ================= */

function renderJournal() {
  return `
    <section>
      <h1 class="page-title">记录手账</h1>
      <p class="page-sub">照护、照片、花费和健康，都按时间存好。</p>
      <label class="card" style="display:flex;align-items:center;gap:10px;padding:12px 14px">
        ${icon('i-cal')}
        <input id="journalSearch" type="search" placeholder="搜索记录内容" value="${esc(journalQuery)}" style="flex:1;border:0;outline:none;background:transparent;font-size:14px" aria-label="搜索记录">
      </label>
      <div class="filters" id="journalFilters">
        ${['all', 'photo', 'spend', 'care', 'health', 'note'].map((f) => {
          const labels = { all: '全部', photo: '照片', spend: '花费', care: '照护', health: '健康', note: '日常' };
          return `<button type="button" data-action="journal-filter" data-value="${f}" class="${journalFilter === f ? 'active' : ''}">${labels[f]}</button>`;
        }).join('')}
      </div>
      <div id="journalList">${journalListHTML()}</div>
    </section>`;
}

function journalListHTML() {
  let entries = state.entries;
  if (journalFilter !== 'all') entries = entries.filter((e) => e.type === journalFilter);
  if (journalQuery.trim()) {
    const q = journalQuery.trim().toLowerCase();
    entries = entries.filter((e) => (e.text || '').toLowerCase().includes(q));
  }
  if (!entries.length) return emptyHTML(journalQuery ? '没有匹配的记录' : '这个分类还没有记录');
  const groups = entriesByDayFrom(entries);
  return groups.map(([day, list]) => `
    <div class="day-group">
      <p class="day-label">${esc(fmtDateCN(day))}</p>
      ${list.map((e) => entryCardHTML(e)).join('')}
    </div>`).join('');
}

function entriesByDayFrom(entries) {
  const map = new Map();
  for (const e of entries) {
    const key = dateKeyOf(new Date(e.ts));
    if (!map.has(key)) map.set(key, []);
    map.get(key).push(e);
  }
  return [...map.entries()].sort((a, b) => b[0].localeCompare(a[0]));
}

/* ================= 宠物 ================= */

function renderPet() {
  const pet = state.pet;
  const speciesInfo = SPECIES[pet.species] || SPECIES.other;
  const color = avatarColor(pet.name || '宠物');
  const birthdayText = pet.birthday ? `${pet.birthday}（${ageText(pet.birthday)}）` : '未填写';
  const recentWeights = state.weights.slice(-8).reverse();

  return `
    <section>
      <div class="card center">
        <div class="avatar-lg" style="background:${color}">${esc((pet.name || '宠')[0])}</div>
        <h1 class="page-title" style="margin-bottom:2px">${esc(pet.name)}</h1>
        <p class="muted" style="margin:0 0 12px">${speciesInfo.label}${pet.breed ? ' · ' + esc(pet.breed) : ''}</p>
        <button class="btn secondary" type="button" data-action="edit-profile">${icon('i-note')} 编辑档案</button>
      </div>

      <div class="card">
        <div class="card-head"><h2>基本信息</h2></div>
        <div class="weight-row"><span class="muted">物种</span><span>${speciesInfo.label}</span></div>
        <div class="weight-row"><span class="muted">品种</span><span>${pet.breed ? esc(pet.breed) : '未填写'}</span></div>
        <div class="weight-row"><span class="muted">生日</span><span>${birthdayText}</span></div>
        <div class="weight-row"><span class="muted">当前体重</span><span class="w-val">${pet.weight ? pet.weight + ' kg' : '未记录'}</span></div>
      </div>

      <div class="card">
        <div class="card-head"><h2>体重记录</h2><button class="more" type="button" data-action="add-weight">+ 记录</button></div>
        ${recentWeights.length ? recentWeights.map((w) => `<div class="weight-row"><span class="w-date">${esc(fmtFullDate(w.date))}</span><span class="w-val">${w.kg} kg</span></div>`).join('') : emptyHTML('记录体重可以观察成长趋势')}
      </div>

      <div class="card">
        <div class="card-head"><h2>家庭成员</h2><button class="more" type="button" data-action="add-member">+ 添加</button></div>
        <p class="muted small" style="margin:0 0 8px">成员仅保存在本机，用于区分谁完成了照护。</p>
        ${state.members.map((m) => `
          <div class="weight-row">
            <span>${esc(m.name)}${m.id === state.activeMember ? ' <span class="tag">当前</span>' : ''}</span>
            <span>
              <span class="muted small" style="margin-right:8px">${m.role === 'owner' ? '主人' : m.role === 'caregiver' ? '照护人' : '围观'}</span>
              ${m.id !== state.activeMember ? `<button class="btn ghost small" type="button" data-action="switch-member" data-id="${m.id}">切换</button>` : ''}
            </span>
          </div>`).join('')}
      </div>
    </section>`;
  }

function ageText(birthday) {
  const [y, m, d] = birthday.split('-').map(Number);
  if (!y) return '';
  const now = new Date();
  let age = now.getFullYear() - y;
  if (now.getMonth() + 1 < m || (now.getMonth() + 1 === m && now.getDate() < d)) age -= 1;
  return age >= 0 ? `${age} 岁` : '';
}

/* ================= 我的 ================= */

function renderMe() {
  const ai = state.ai;
  const providerOptions = Object.entries(AI_PROVIDERS).map(([key, p]) =>
    `<option value="${key}" ${ai.provider === key ? 'selected' : ''}>${p.label}</option>`).join('');

  return `
    <section>
      <h1 class="page-title">我的</h1>
      <p class="page-sub">AI 配置、数据与本地存储。</p>

      <div class="card set-card">
        <div class="card-head"><h2>AI 助手设置</h2></div>
        <div class="field">
          <label>服务商</label>
          <select id="aiProvider">${providerOptions}</select>
        </div>
        <div class="field">
          <label>API 地址（OpenAI 兼容）</label>
          <input id="aiBaseUrl" type="text" value="${esc(ai.baseUrl)}" placeholder="https://api.example.com/v1" autocomplete="off">
        </div>
        <div class="field">
          <label>API Key</label>
          <input id="aiApiKey" type="password" value="${esc(ai.apiKey)}" placeholder="sk-..." autocomplete="off">
        </div>
        <div class="field">
          <label>模型</label>
          <input id="aiModel" type="text" value="${esc(ai.model)}" placeholder="gpt-4o-mini" autocomplete="off">
        </div>
        <p class="muted small">配置只保存在本机浏览器。若接口不支持浏览器跨域访问，请填入支持 CORS 的代理地址。</p>
        <div class="form-actions">
          <button class="btn secondary" type="button" data-action="ai-test">测试连接</button>
          <button class="btn" type="button" data-action="ai-save">保存</button>
        </div>
        <div class="test-result" id="aiTestResult"></div>
      </div>

      <div class="card">
        <div class="card-head"><h2>数据</h2></div>
        <div class="set-row">
          <div><div class="set-label">导出数据</div><div class="set-sub">下载全部记录为 JSON 文件</div></div>
          <button class="btn secondary" type="button" data-action="export-data">导出</button>
        </div>
        <div class="set-row">
          <div><div class="set-label">导入数据</div><div class="set-sub">从 JSON 文件恢复（会覆盖当前数据）</div></div>
          <button class="btn secondary" type="button" data-action="import-data">导入</button>
        </div>
        <div class="set-row">
          <div><div class="set-label" style="color:var(--danger)">清空数据</div><div class="set-sub">删除本机全部记录，不可恢复</div></div>
          <button class="btn danger" type="button" data-action="clear-data">清空</button>
        </div>
      </div>

      <div class="card">
        <div class="card-head"><h2>关于</h2></div>
        <p class="muted small" style="margin:0">同窝 Covey · 本地优先的宠物日常。所有数据保存在这台设备的浏览器中，AI 功能需要你在上方配置自己的 API。</p>
      </div>
    </section>`;
}

/* ================= AI ================= */

function renderAi() {
  const configured = Boolean(state.ai.apiKey && state.ai.baseUrl);
  if (!configured) {
    return `
      <section>
        <h1 class="page-title">AI 助手 Pawly</h1>
        <p class="page-sub">结合宠物档案和照护记录，给出有依据的建议。</p>
        <div class="card center ai-empty" style="padding:32px 20px">
          <div class="ai-empty-icon">${icon('i-wand')}</div>
          <h2 style="margin:10px 0 6px;font-size:16px">还没有配置 AI</h2>
          <p class="muted small" style="margin:0 0 16px">在「我的 → AI 助手设置」中填入 API 地址、Key 和模型即可使用。</p>
          <button class="btn" type="button" data-action="goto-me">去设置</button>
        </div>
        ${ruleInsightCard()}
      </section>`;
  }

  const messages = state.chat.slice(-40).map((m) => `
    <div class="msg ${m.role === 'user' ? 'user' : 'ai'}">
      ${esc(m.content)}
      <div class="meta">${m.role === 'user' ? esc(memberName(state, m.by || 'me')) : 'Pawly'} · ${fmtTimeFull(m.ts)}</div>
    </div>`).join('');

  return `
    <section style="display:flex;flex-direction:column;min-height:70vh">
      <h1 class="page-title">AI 助手 Pawly</h1>
      <p class="page-sub">基于真实记录回答，建议仅供参考。</p>
      <div class="chips">
        <button type="button" data-action="ai-quick" data-q="总结我家宠物最近一周的状态">总结最近一周</button>
        <button type="button" data-action="ai-quick" data-q="根据记录，给我几点照护上的建议">照护建议</button>
        <button type="button" data-action="ai-quick" data-q="这周有哪些照护环节容易被忽略？">查漏补缺</button>
        <button type="button" data-action="ai-quick" data-q="记录一条今天的日常感受">随手记录</button>
      </div>
      <div class="ai-chat" id="chatList">
        ${messages || `<div class="msg ai">你好，我是 Pawly。问我关于${esc(state.pet.name)}的照护、记录或安排都可以。</div>`}
      </div>
      <div class="ai-input-bar">
        <textarea id="aiInput" rows="1" placeholder="问点什么…" aria-label="输入消息"></textarea>
        <button class="send-btn" type="button" data-action="ai-send" aria-label="发送">${icon('i-send')}</button>
      </div>
    </section>`;
}

function ruleInsightCard() {
  return `<div class="card"><div class="card-head"><h2>不用 AI 也能看到</h2></div><p class="muted" style="margin:0">${ruleInsight(state)}</p></div>`;
}

function fmtTimeFull(ts) {
  const d = new Date(ts);
  const p = (n) => String(n).padStart(2, '0');
  return `${p(d.getMonth() + 1)}-${p(d.getDate())} ${p(d.getHours())}:${p(d.getMinutes())}`;
}

async function sendAi(text) {
  const content = (text || '').trim();
  if (!content || chatBusy) return;
  if (!state.ai.apiKey || !state.ai.baseUrl) { toast('请先在「我的」里配置 AI'); return; }
  chatBusy = true;
  state.chat.push({ role: 'user', content, by: state.activeMember, ts: Date.now() });
  state.chat.push({ role: 'assistant', content: '…', ts: Date.now(), pending: true });
  if (state.chat.length > 120) state.chat = state.chat.slice(-120);
  persist();
  renderChatTail();

  const history = state.chat
    .filter((m) => !m.pending)
    .slice(-20)
    .map((m) => ({ role: m.role === 'user' ? 'user' : 'assistant', content: m.content }));
  const messages = [
    { role: 'system', content: buildSystemPrompt(state) },
    ...history,
  ];

  try {
    const reply = await chatOnce(state.ai, messages);
    const pending = [...state.chat].reverse().find((m) => m.pending);
    if (pending) {
      pending.content = reply;
      pending.pending = false;
      pending.ts = Date.now();
    }
  } catch (err) {
    const pending = [...state.chat].reverse().find((m) => m.pending);
    if (pending) {
      pending.content = `请求出错了：${err.message}\n\n可以检查「我的 → AI 助手设置」里的配置，或确认接口支持浏览器跨域访问。`;
      pending.pending = false;
    }
  } finally {
    chatBusy = false;
    persist();
    renderChatTail();
  }
}

function renderChatTail() {
  const list = document.getElementById('chatList');
  if (!list) { render(); return; }
  const messages = state.chat.slice(-40).map((m) => `
    <div class="msg ${m.role === 'user' ? 'user' : 'ai'}${m.pending ? ' thinking' : ''}">
      ${esc(m.content)}
      <div class="meta">${m.role === 'user' ? esc(memberName(state, m.by || 'me')) : 'Pawly'} · ${fmtTimeFull(m.ts)}</div>
    </div>`).join('');
  list.innerHTML = messages || `<div class="msg ai">你好，我是 Pawly。</div>`;
  list.scrollTop = list.scrollHeight;
  const input = document.getElementById('aiInput');
  if (input) input.focus();
}

/* ================= 弹窗：记录 ================= */

let pendingPhotoData = null;

function pickPhoto() {
  const input = document.getElementById('photoInput');
  input.value = '';
  input.onchange = () => {
    const file = input.files && input.files[0];
    if (!file) return;
    fileToDataUrl(file).then((dataUrl) => {
      pendingPhotoData = dataUrl;
      openPhotoNoteModal(dataUrl);
    }).catch(() => toast('图片读取失败'));
  };
  input.click();
}

function fileToDataUrl(file, maxSize = 900, quality = 0.75) {
  return new Promise((resolve, reject) => {
    const reader = new FileReader();
    reader.onload = () => {
      const img = new Image();
      img.onload = () => {
        const scale = Math.min(1, maxSize / Math.max(img.width, img.height));
        const w = Math.max(1, Math.round(img.width * scale));
        const h = Math.max(1, Math.round(img.height * scale));
        const canvas = document.createElement('canvas');
        canvas.width = w; canvas.height = h;
        canvas.getContext('2d').drawImage(img, 0, 0, w, h);
        resolve(canvas.toDataURL('image/jpeg', quality));
      };
      img.onerror = reject;
      img.src = reader.result;
    };
    reader.onerror = reject;
    reader.readAsDataURL(file);
  });
}

function openPhotoNoteModal(photo) {
  const modal = openModal(`
    <div class="modal-head"><h3>记一张照片</h3><button class="icon-btn" type="button" data-mact="close">${icon('i-close')}</button></div>
    <img class="photo-preview" src="${photo}" alt="预览">
    <div class="field"><textarea id="mPhotoText" rows="3" placeholder="这张照片里发生了什么？（可留空）"></textarea></div>
    <div class="form-actions">
      <button class="btn secondary" type="button" data-mact="close">取消</button>
      <button class="btn" type="button" data-mact="save-photo">保存</button>
    </div>`);
  bindModalEvents(modal, {
    close: () => closeModal(),
    'save-photo': (e, el, m) => {
      const text = (m.querySelector('#mPhotoText').value || '').trim();
      addEntry({ type: 'photo', text, photo: pendingPhotoData });
      closeModal();
    },
  });
  modal.querySelector('#mPhotoText').focus();
}

function openNoteModal() {
  let type = 'note';
  const modal = openModal(`
    <div class="modal-head"><h3>记一笔</h3><button class="icon-btn" type="button" data-mact="close">${icon('i-close')}</button></div>
    <div class="type-picker" id="mTypePicker">
      ${['note', 'spend', 'health'].map((t) => `<button type="button" data-mact="pick-type" data-value="${t}" class="${t === type ? 'active' : ''}">${ENTRY_TYPES[t].label}</button>`).join('')}
    </div>
    <div class="field" id="mAmountField" hidden>
      <label>金额（元）</label>
      <input id="mAmount" type="number" min="0" step="0.01" placeholder="0.00">
    </div>
    <div class="field">
      <label>内容</label>
      <textarea id="mNoteText" rows="3" placeholder="${typePlaceholder('note')}"></textarea>
    </div>
    <div class="form-actions">
      <button class="btn secondary" type="button" data-mact="close">取消</button>
      <button class="btn" type="button" data-mact="save-note">保存</button>
    </div>`);

  function refreshTypeUI() {
    modal.querySelectorAll('#mTypePicker button').forEach((b) => b.classList.toggle('active', b.dataset.value === type));
    modal.querySelector('#mAmountField').hidden = type !== 'spend';
    const ta = modal.querySelector('#mNoteText');
    ta.placeholder = typePlaceholder(type);
  }

  bindModalEvents(modal, {
    close: () => closeModal(),
    'pick-type': (e, el) => { type = el.dataset.value; refreshTypeUI(); },
    'save-note': (e, el, m) => {
      const text = (m.querySelector('#mNoteText').value || '').trim();
      const amountRaw = m.querySelector('#mAmount').value;
      const amount = type === 'spend' && amountRaw !== '' ? Number(amountRaw) : undefined;
      if (!text && (amount == null || Number.isNaN(amount))) { toast('写点什么再保存'); return; }
      addEntry({ type, text, amount });
      closeModal();
    },
  });
  modal.querySelector('#mNoteText').focus();

  function typePlaceholder(t) {
    return { note: '今天发生了什么？', spend: '买了什么？', health: '疫苗、驱虫、就诊或异常情况…' }[t] || '';
  }
}

function addEntry({ type, text = '', photo, amount }) {
  state.entries.unshift({
    id: uid('e'), ts: Date.now(), type,
    text: text || '',
    photo: photo || undefined,
    amount: amount != null && !Number.isNaN(amount) ? amount : undefined,
    by: state.activeMember,
  });
  if (state.entries.length > 800) state.entries.length = 800;
  persist();
  refresh();
  toast('已记录');
}

function openEntryModal(id) {
  const e = state.entries.find((x) => x.id === id);
  if (!e) return;
  const time = new Date(e.ts);
  const p = (n) => String(n).padStart(2, '0');
  const timeLabel = `${fmtFullDate(dateKeyOf(time))} ${p(time.getHours())}:${p(time.getMinutes())}`;
  let confirmDelete = false;

  const modal = openModal(`
    <div class="modal-head"><h3>${ENTRY_TYPES[e.type]?.label || '记录'}</h3><button class="icon-btn" type="button" data-mact="close">${icon('i-close')}</button></div>
    <p class="muted small" style="margin:0 0 10px">${timeLabel} · ${esc(memberName(state, e.by))}</p>
    ${e.photo ? `<img class="photo-preview" src="${e.photo}" alt="照片" data-mact="zoom">` : ''}
    ${e.text ? `<p style="font-size:14px;line-height:1.6;white-space:pre-wrap;margin:0 0 10px">${esc(e.text)}</p>` : ''}
    ${e.amount != null ? `<p style="margin:0 0 10px"><span class="amount" style="font-size:18px">¥${Number(e.amount).toFixed(2)}</span></p>` : ''}
    <div class="form-actions">
      <button class="btn danger" type="button" data-mact="delete">${confirmDelete ? '确认删除？' : '删除这条记录'}</button>
    </div>`);

  bindModalEvents(modal, {
    close: () => closeModal(),
    zoom: () => e.photo && openLightbox(e.photo, e.text || '照片'),
    delete: (ev, el) => {
      if (!confirmDelete) {
        confirmDelete = true;
        el.textContent = '确认删除？';
        setTimeout(() => { el.textContent = '删除这条记录'; confirmDelete = false; }, 2500);
        return;
      }
      state.entries = state.entries.filter((x) => x.id !== id);
      persist();
      closeModal();
      refresh();
      toast('已删除');
    },
  });
}

/* ================= 弹窗：提醒 ================= */

function openReminderForm() {
  const modal = openModal(`
    <div class="modal-head"><h3>新建提醒</h3><button class="icon-btn" type="button" data-mact="close">${icon('i-close')}</button></div>
    <div class="field"><label>事项</label><input id="mRemTitle" type="text" placeholder="例如：猫三联疫苗加强"></div>
    <div class="field-row">
      <div class="field"><label>类型</label>
        <select id="mRemCat">${Object.entries(REMINDER_CATEGORIES).map(([k, v]) => `<option value="${k}">${v}</option>`).join('')}</select>
      </div>
      <div class="field"><label>日期</label><input id="mRemDue" type="date" value="${todayKey()}"></div>
    </div>
    <div class="field"><label>备注（可选）</label><input id="mRemNote" type="text" placeholder="例如：带病历本"></div>
    <div class="form-actions">
      <button class="btn secondary" type="button" data-mact="close">取消</button>
      <button class="btn" type="button" data-mact="save">保存</button>
    </div>`);
  bindModalEvents(modal, {
    close: () => closeModal(),
    save: (e, el, m) => {
      const title = (m.querySelector('#mRemTitle').value || '').trim();
      const due = m.querySelector('#mRemDue').value;
      if (!title) { toast('请填写事项'); return; }
      if (!due) { toast('请选择日期'); return; }
      state.reminders.push({
        id: uid('r'), title,
        category: m.querySelector('#mRemCat').value,
        due, done: false,
        note: (m.querySelector('#mRemNote').value || '').trim(),
      });
      persist(); closeModal(); refresh(); toast('提醒已添加');
    },
  });
  modal.querySelector('#mRemTitle').focus();
}

/* ================= 弹窗：宠物档案 / 体重 / 成员 ================= */

function openProfileForm() {
  const pet = state.pet;
  const modal = openModal(`
    <div class="modal-head"><h3>宠物档案</h3><button class="icon-btn" type="button" data-mact="close">${icon('i-close')}</button></div>
    <div class="field"><label>名字</label><input id="mPetName" type="text" value="${esc(pet.name)}"></div>
    <div class="field-row">
      <div class="field"><label>物种</label>
        <select id="mPetSpecies">${Object.entries(SPECIES).map(([k, v]) => `<option value="${k}" ${pet.species === k ? 'selected' : ''}>${v.label}</option>`).join('')}</select>
      </div>
      <div class="field"><label>品种</label><input id="mPetBreed" type="text" value="${esc(pet.breed)}" placeholder="如：布偶猫"></div>
    </div>
    <div class="field"><label>生日</label><input id="mPetBirthday" type="date" value="${esc(pet.birthday)}"></div>
    <div class="field"><label>当前体重（kg）</label><input id="mPetWeight" type="number" min="0" step="0.1" value="${esc(pet.weight)}"></div>
    <div class="form-actions">
      <button class="btn secondary" type="button" data-mact="close">取消</button>
      <button class="btn" type="button" data-mact="save">保存</button>
    </div>`);
  bindModalEvents(modal, {
    close: () => closeModal(),
    save: (e, el, m) => {
      const name = (m.querySelector('#mPetName').value || '').trim();
      if (!name) { toast('请填写名字'); return; }
      const species = m.querySelector('#mPetSpecies').value;
      const oldSpecies = state.pet.species;
      state.pet.name = name;
      state.pet.species = species;
      state.pet.breed = (m.querySelector('#mPetBreed').value || '').trim();
      state.pet.birthday = m.querySelector('#mPetBirthday').value || '';
      state.pet.weight = m.querySelector('#mPetWeight').value || '';
      // 物种变化时同步默认照护任务
      if (species !== oldSpecies) state.tasks = defaultTasks(species);
      persist(); closeModal(); refresh(); toast('档案已保存');
    },
  });
}

function openWeightForm() {
  const today = todayKey();
  const modal = openModal(`
    <div class="modal-head"><h3>记录体重</h3><button class="icon-btn" type="button" data-mact="close">${icon('i-close')}</button></div>
    <div class="field-row">
      <div class="field"><label>日期</label><input id="mWDate" type="date" value="${today}"></div>
      <div class="field"><label>体重（kg）</label><input id="mWKg" type="number" min="0" step="0.1" placeholder="4.2"></div>
    </div>
    <div class="form-actions">
      <button class="btn secondary" type="button" data-mact="close">取消</button>
      <button class="btn" type="button" data-mact="save">保存</button>
    </div>`);
  bindModalEvents(modal, {
    close: () => closeModal(),
    save: (e, el, m) => {
      const date = m.querySelector('#mWDate').value;
      const kg = Number(m.querySelector('#mWKg').value);
      if (!date || !kg || kg <= 0) { toast('请填写日期和体重'); return; }
      state.weights = state.weights.filter((w) => w.date !== date);
      state.weights.push({ id: uid('w'), date, kg });
      state.weights.sort((a, b) => a.date.localeCompare(b.date));
      state.pet.weight = String(kg);
      persist(); closeModal(); refresh(); toast('体重已记录');
    },
  });
}

function openMemberForm() {
  const modal = openModal(`
    <div class="modal-head"><h3>添加成员</h3><button class="icon-btn" type="button" data-mact="close">${icon('i-close')}</button></div>
    <div class="field"><label>名字</label><input id="mMemName" type="text" placeholder="例如：妈妈"></div>
    <div class="field"><label>角色</label>
      <select id="mMemRole">
        <option value="caregiver">照护人（可以记记录）</option>
        <option value="viewer">围观（只看）</option>
      </select>
    </div>
    <p class="muted small">成员只保存在本机，用来区分谁做了什么。</p>
    <div class="form-actions">
      <button class="btn secondary" type="button" data-mact="close">取消</button>
      <button class="btn" type="button" data-mact="save">添加</button>
    </div>`);
  bindModalEvents(modal, {
    close: () => closeModal(),
    save: (e, el, m) => {
      const name = (m.querySelector('#mMemName').value || '').trim();
      if (!name) { toast('请填写名字'); return; }
      if (state.members.some((x) => x.name === name)) { toast('已有同名成员'); return; }
      state.members.push({ id: uid('m'), name, role: m.querySelector('#mMemRole').value });
      persist(); closeModal(); refresh(); toast('已添加');
    },
  });
}

/* ================= 路由与事件 ================= */

const routes = {
  today: renderToday,
  journal: renderJournal,
  ai: renderAi,
  pet: renderPet,
  me: renderMe,
};

function render() {
  const fn = routes[route] || renderToday;
  $view.innerHTML = fn();
  document.querySelectorAll('.tab').forEach((t) => t.classList.toggle('active', t.dataset.route === route));
  if (route === 'journal') bindJournalEvents();
  if (route === 'me') bindMeEvents();
  if (route === 'ai') {
    bindAiEvents();
    if (pendingAiPrompt) {
      const q = pendingAiPrompt;
      pendingAiPrompt = null;
      setTimeout(() => sendAi(q), 60);
    }
  }
  window.scrollTo(0, 0);
}

function updatePetChip() {
  const pet = state.pet;
  const color = avatarColor(pet.name || '宠物');
  petChip.innerHTML = `<span class="avatar" style="background:${color}">${esc((pet.name || '宠')[0])}</span><span>${esc(pet.name)}</span>${icon('i-chev')}`;
}

function bindJournalEvents() {
  const search = document.getElementById('journalSearch');
  if (search) {
    search.addEventListener('input', () => {
      journalQuery = search.value;
      document.getElementById('journalList').innerHTML = journalListHTML();
    });
  }
}

function readAiForm() {
  return {
    provider: document.getElementById('aiProvider')?.value || state.ai.provider,
    baseUrl: document.getElementById('aiBaseUrl')?.value ?? state.ai.baseUrl,
    apiKey: document.getElementById('aiApiKey')?.value ?? state.ai.apiKey,
    model: document.getElementById('aiModel')?.value ?? state.ai.model,
  };
}

function bindMeEvents() {
  const provider = document.getElementById('aiProvider');
  if (provider) {
    provider.addEventListener('change', () => {
      const preset = AI_PROVIDERS[provider.value];
      if (preset && provider.value !== 'custom') {
        document.getElementById('aiBaseUrl').value = preset.baseUrl;
        document.getElementById('aiModel').value = preset.model;
      }
    });
  }
}

function bindAiEvents() {
  const input = document.getElementById('aiInput');
  if (input) {
    input.addEventListener('keydown', (e) => {
      if (e.key === 'Enter' && !e.shiftKey) {
        e.preventDefault();
        sendAi(input.value);
        input.value = '';
      }
    });
  }
}

function handleAction(action, el) {
  switch (action) {
    case 'nav': navigate(el.dataset.route); break;
    case 'goto-pet': navigate('pet'); break;
    case 'goto-me': navigate('me'); break;
    case 'toggle-task': {
      const id = el.dataset.id;
      if (isTaskDone(state, id)) undoTask(state, id);
      else completeTask(state, id);
      persist(); refresh();
      break;
    }
    case 'quick-photo': pickPhoto(); break;
    case 'quick-note': openNoteModal(); break;
    case 'ask-ai-today':
      pendingAiPrompt = `请根据我家宠物${state.pet.name}最近的照护记录和待办提醒，给我 3 条简短、可执行的建议。`;
      navigate('ai');
      break;
    case 'ai-quick': sendAi(el.dataset.q); {
      const input = document.getElementById('aiInput');
      if (input) input.value = '';
      break;
    }
    case 'ai-send': {
      const input = document.getElementById('aiInput');
      if (input) { sendAi(input.value); input.value = ''; }
      break;
    }
    case 'open-entry': openEntryModal(el.dataset.id); break;
    case 'view-photo': openLightbox(el.dataset.src, '照片'); break;
    case 'journal-filter': journalFilter = el.dataset.value; refresh(); break;
    case 'open-reminder-form': openReminderForm(); break;
    case 'reminder-done': {
      const r = state.reminders.find((x) => x.id === el.dataset.id);
      if (r) { r.done = true; persist(); refresh(); toast('已完成'); }
      break;
    }
    case 'reminder-del': {
      state.reminders = state.reminders.filter((x) => x.id !== el.dataset.id);
      persist(); refresh(); toast('已删除');
      break;
    }
    case 'edit-profile': openProfileForm(); break;
    case 'add-weight': openWeightForm(); break;
    case 'add-member': openMemberForm(); break;
    case 'switch-member': {
      state.activeMember = el.dataset.id;
      persist(); refresh(); toast(`已切换到${memberName(state, state.activeMember)}`);
      break;
    }
    case 'ai-save': {
      const form = readAiForm();
      state.ai = { ...state.ai, ...form };
      persist(); toast('AI 配置已保存');
      break;
    }
    case 'ai-test': {
      const form = readAiForm();
      const result = document.getElementById('aiTestResult');
      if (result) { result.className = 'test-result'; result.textContent = '测试中…'; }
      testConnection(form).then((res) => {
        const target = document.getElementById('aiTestResult');
        if (target) {
          target.className = 'test-result ' + (res.ok ? 'ok' : 'err');
          target.textContent = res.message;
        }
        toast(res.ok ? '连接成功' : '连接失败');
      });
      break;
    }
    case 'export-data': {
      const blob = new Blob([exportJSON(state)], { type: 'application/json' });
      const a = document.createElement('a');
      a.href = URL.createObjectURL(blob);
      a.download = `covey-backup-${todayKey()}.json`;
      a.click();
      URL.revokeObjectURL(a.href);
      toast('已导出');
      break;
    }
    case 'import-data': document.getElementById('importInput').click(); break;
    case 'clear-data': {
      const ok = window.confirm('确定清空所有数据吗？此操作不可恢复。');
      if (!ok) break;
      resetState();
      state = defaultState();
      journalFilter = 'all'; journalQuery = '';
      persist(); refresh(); toast('已清空');
      break;
    }
    default: break;
  }
}

// 全局点击委托
document.addEventListener('click', (e) => {
  const el = e.target.closest('[data-action]');
  if (!el) return;
  handleAction(el.dataset.action, el);
});

// 导入文件
document.getElementById('importInput').addEventListener('change', (e) => {
  const file = e.target.files && e.target.files[0];
  e.target.value = '';
  if (!file) return;
  const reader = new FileReader();
  reader.onload = () => {
    try {
      const data = JSON.parse(reader.result);
      if (!data || typeof data !== 'object' || !data.pet) throw new Error('bad');
      state = { ...defaultState(), ...data };
      persist(); refresh(); toast('导入成功');
    } catch {
      toast('文件格式不正确');
    }
  };
  reader.readAsText(file);
});

// 路由
function routeFromHash() {
  const h = location.hash.replace(/^#\/?/, '');
  return routes[h] ? h : 'today';
}
window.addEventListener('hashchange', () => { route = routeFromHash(); render(); });

// 启动
route = routeFromHash();
updatePetChip();
render();
