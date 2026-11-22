// 同窝 Covey · 本地状态存储（localStorage 单用户/本机多成员演示）

const LS_KEY = 'covey-state-v1';

export const TASK_TYPES = {
  feeding: { label: '喂食', tagClass: 'feeding' },
  water: { label: '换水', tagClass: 'water' },
  clean: { label: '清洁', tagClass: 'clean' },
  walk: { label: '遛弯', tagClass: 'walk' },
  companion: { label: '陪伴', tagClass: 'companion' },
};

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

export const SPECIES = {
  cat: { label: '猫', icon: 'i-cat' },
  dog: { label: '狗', icon: 'i-dog' },
  rabbit: { label: '兔子', icon: 'i-rabbit' },
  other: { label: '其他', icon: 'i-paw' },
};

const AVATAR_COLORS = ['#d96f4e', '#6f8f5f', '#5b7fa6', '#c99a3f', '#9b6b8f', '#4e8f8a'];

export function defaultTasks(species) {
  const base = [
    { id: 'breakfast', title: '早餐', type: 'feeding', time: '07:30' },
    { id: 'water', title: '换水', type: 'water', time: '12:00' },
    { id: 'dinner', title: '晚餐', type: 'feeding', time: '18:30' },
  ];
  const evening = species === 'dog'
    ? { id: 'walk', title: '遛弯', type: 'walk', time: '20:00' }
    : species === 'cat'
      ? { id: 'litter', title: '清理猫砂', type: 'clean', time: '20:00' }
      : { id: 'play', title: '陪伴玩耍', type: 'companion', time: '20:00' };
  return [...base, evening];
}

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
    tasks: defaultTasks('cat'),
    completions: {},   // { 'YYYY-MM-DD': { taskId: { by, at } } }
    entries: [],       // { id, ts, type, text, photo, amount, by, taskId }
    reminders: [],     // { id, title, category, due, done, note }
    weights: [],       // { id, date, kg }
    ai: { provider: 'deepseek', baseUrl: AI_PROVIDERS.deepseek.baseUrl, apiKey: '', model: AI_PROVIDERS.deepseek.model },
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
    state.tasks = Array.isArray(parsed.tasks) && parsed.tasks.length ? parsed.tasks : defaultTasks(state.pet.species);
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

export function todayCompletions(state, key = todayKey()) {
  return state.completions[key] || {};
}

export function isTaskDone(state, taskId, key = todayKey()) {
  return Boolean(todayCompletions(state, key)[taskId]);
}

export function completeTask(state, taskId) {
  const key = todayKey();
  const by = state.activeMember;
  const at = Date.now();
  state.completions[key] = { ...(state.completions[key] || {}), [taskId]: { by, at } };
  const task = state.tasks.find((t) => t.id === taskId);
  if (task) {
    state.entries.unshift({
      id: uid('e'), ts: at, type: 'care', text: task.title,
      taskId, by,
    });
  }
}

export function undoTask(state, taskId) {
  const key = todayKey();
  if (!state.completions[key]) return;
  delete state.completions[key][taskId];
  state.entries = state.entries.filter((e) => !(e.type === 'care' && e.taskId === taskId && dateKeyOf(new Date(e.ts)) === key));
}

export function careProgress(state, key = todayKey()) {
  const done = state.tasks.filter((t) => isTaskDone(state, t.id, key)).length;
  return { done, total: state.tasks.length };
}

// 连续照顾天数：从今天（或昨天）往前，全部任务完成的天数
export function careStreak(state) {
  let streak = 0;
  const cursor = new Date();
  const todayDone = state.tasks.every((t) => isTaskDone(state, t.id, todayKey()));
  if (!todayDone) cursor.setDate(cursor.getDate() - 1);
  for (;;) {
    const key = dateKeyOf(cursor);
    const allDone = state.tasks.every((t) => isTaskDone(state, t.id, key));
    if (!allDone) break;
    streak += 1;
    cursor.setDate(cursor.getDate() - 1);
  }
  return streak;
}

export function weekStats(state) {
  let done = 0, total = 0;
  for (let i = 6; i >= 0; i--) {
    const key = daysAgoKey(i);
    const comp = state.completions[key] || {};
    for (const t of state.tasks) {
      total += 1;
      if (comp[t.id]) done += 1;
    }
  }
  return { done, total, rate: total ? Math.round((done / total) * 100) : 0 };
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
