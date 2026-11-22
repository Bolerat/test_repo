// 同窝 Covey · 本地状态存储（localStorage 单用户/本机多成员演示）

const LS_KEY = 'covey-state-v1';

export const ENTRY_TYPES = {
  care: { label: '照护', icon: 'i-check', tagClass: 'care' },
  note: { label: '日常', icon: 'i-note', tagClass: 'note' },
  photo: { label: '照片', icon: 'i-camera', tagClass: 'photo' },
  spend: { label: '花费', icon: 'i-coin', tagClass: 'spend' },
  health: { label: '健康', icon: 'i-health', tagClass: 'health' },
};

export const REMINDER_CATEGORIES = {
  vaccine: '疫苗',
  deworm: '驱虫',
  grooming: '洗护',
  medical: '就诊',
  custom: '自定义',
};

export const AI_PROVIDERS = {
  deepseek: { label: 'DeepSeek', baseUrl: 'https://api.deepseek.com/v1', model: 'deepseek-chat' },
  openai: { label: 'OpenAI', baseUrl: 'https://api.openai.com/v1', model: 'gpt-4o-mini' },
  glm: { label: '智谱 GLM', baseUrl: 'https://open.bigmodel.cn/api/paas/v4', model: 'glm-4-flash' },
  qwen: { label: '通义千问', baseUrl: 'https://dashscope.aliyuncs.com/compatible-mode/v1', model: 'qwen-plus' },
  custom: { label: '自定义（OpenAI 兼容）', baseUrl: '', model: '' },
};

// Pawly 的语气选项：hint 会注入系统提示词
export const AI_TONES = {
  warm: { label: '温暖陪伴', hint: '像家人一样自然关心，语气温和，不说教' },
  lively: { label: '活泼俏皮', hint: '轻松幽默，可以偶尔用 emoji，但不过分' },
  concise: { label: '简洁利落', hint: '直奔重点，少寒暄，先给答案' },
  calm: { label: '冷静专业', hint: '条理清晰，先结论后依据，语气平稳' },
};

export const SPECIES = {
  cat: { label: '猫', icon: 'i-cat' },
  dog: { label: '狗', icon: 'i-dog' },
  rabbit: { label: '兔子', icon: 'i-rabbit' },
  other: { label: '其他', icon: 'i-paw' },
};

const AVATAR_COLORS = ['#d96f4e', '#6f8f5f', '#5b7fa6', '#c99a3f', '#9b6b8f', '#4e8f8a'];

export function defaultState() {
  return {
    version: 1,
    pet: {
      name: '布丁',
      species: 'cat',
      breed: '',
      birthday: '',
      weight: '',
    },
    activeMember: 'me',
    members: [{ id: 'me', name: '我', role: 'owner' }],
    entries: [],       // { id, ts, type, text, photo, amount, by }
    reminders: [],     // { id, title, category, due, done, note }
    remindersEnabled: true,
    weights: [],       // { id, date, kg }
    ai: { provider: 'deepseek', baseUrl: AI_PROVIDERS.deepseek.baseUrl, apiKey: '', model: AI_PROVIDERS.deepseek.model, tone: 'warm' },
    chat: [],          // [{ role, content, ts }]
  };
}

export function loadState() {
  try {
    const raw = localStorage.getItem(LS_KEY);
    if (!raw) return defaultState();
    const parsed = JSON.parse(raw);
    const state = { ...defaultState(), ...parsed };
    state.pet = { ...defaultState().pet, ...(parsed.pet || {}) };
    state.ai = { ...defaultState().ai, ...(parsed.ai || {}) };
    state.members = Array.isArray(parsed.members) && parsed.members.length ? parsed.members : defaultState().members;
    if (typeof state.remindersEnabled !== 'boolean') state.remindersEnabled = true;
    return state;
  } catch {
    return defaultState();
  }
}

export function saveState(state) {
  try {
    localStorage.setItem(LS_KEY, JSON.stringify(state));
  } catch (err) {
    console.warn('保存失败（可能超出本地存储上限）', err);
  }
}

export function resetState() {
  try { localStorage.removeItem(LS_KEY); } catch { /* ignore */ }
}

/* ---------- 时间工具 ---------- */

export function pad(n) { return String(n).padStart(2, '0'); }

export function dateKeyOf(date = new Date()) {
  return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}`;
}

export function todayKey() { return dateKeyOf(new Date()); }

export function timeKeyOf(date = new Date()) {
  return `${pad(date.getHours())}:${pad(date.getMinutes())}`;
}

export function fmtDateCN(dateStr) {
  const [y, m, d] = dateStr.split('-').map(Number);
  const date = new Date(y, m - 1, d);
  const today = new Date();
  const yesterday = new Date(); yesterday.setDate(yesterday.getDate() - 1);
  if (dateKeyOf(date) === dateKeyOf(today)) return '今天';
  if (dateKeyOf(date) === dateKeyOf(yesterday)) return '昨天';
  const week = ['周日', '周一', '周二', '周三', '周四', '周五', '周六'];
  return `${m}月${d}日 ${week[date.getDay()]}`;
}

export function fmtFullDate(dateStr) {
  const [y, m, d] = dateStr.split('-').map(Number);
  return `${y}年${m}月${d}日`;
}

export function daysAgoKey(n) {
  const d = new Date();
  d.setDate(d.getDate() - n);
  return dateKeyOf(d);
}

/* ---------- 领域逻辑 ---------- */

export function uid(prefix = 'id') {
  return `${prefix}-${Date.now().toString(36)}-${Math.random().toString(36).slice(2, 8)}`;
}

export function memberName(state, id) {
  const m = state.members.find((x) => x.id === id);
  return m ? m.name : '我';
}

export function avatarColor(name) {
  let h = 0;
  for (const ch of name) h = (h * 31 + ch.charCodeAt(0)) >>> 0;
  return AVATAR_COLORS[h % AVATAR_COLORS.length];
}

/* ---------- 记录统计 ---------- */

export function entriesSince(state, days) {
  const since = Date.now() - days * 86400000;
  return state.entries.filter((e) => e.ts >= since);
}

export function weekEntryCount(state) {
  return entriesSince(state, 7).length;
}

// 连续记录天数：今天或昨天有记录就算起点
export function recordStreak(state) {
  let streak = 0;
  const cursor = new Date();
  const hasToday = state.entries.some((e) => dateKeyOf(new Date(e.ts)) === todayKey());
  if (!hasToday) cursor.setDate(cursor.getDate() - 1);
  for (;;) {
    const key = dateKeyOf(cursor);
    if (!state.entries.some((e) => dateKeyOf(new Date(e.ts)) === key)) break;
    streak += 1;
    cursor.setDate(cursor.getDate() - 1);
  }
  return streak;
}

export function upcomingReminders(state, withinDays = 30) {
  const now = todayKey();
  return state.reminders
    .filter((r) => !r.done)
    .map((r) => ({ ...r, overdue: r.due < now }))
    .sort((a, b) => a.due.localeCompare(b.due))
    .slice(0, withinDays === Infinity ? undefined : 50);
}

export function remindersDueSoon(state, days = 7) {
  const limit = daysAgoKey(-days);
  return state.reminders.filter((r) => !r.done && r.due <= limit);
}

export function entriesByDay(state) {
  const map = new Map();
  for (const e of state.entries) {
    const key = dateKeyOf(new Date(e.ts));
    if (!map.has(key)) map.set(key, []);
    map.get(key).push(e);
  }
  return [...map.entries()].sort((a, b) => b[0].localeCompare(a[0]));
}

export function lastWeight(state) {
  if (!state.weights.length) return null;
  return state.weights[state.weights.length - 1];
}

export function daysSinceWeight(state) {
  const last = lastWeight(state);
  if (!last) return null;
  const lastDate = new Date(last.date + 'T00:00:00');
  const now = new Date();
  return Math.floor((now - lastDate) / 86400000);
}

export function exportJSON(state) {
  return JSON.stringify(state, null, 2);
}
