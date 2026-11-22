// 同窝 Covey · AI 助手（OpenAI 兼容 chat/completions 接口）
import { SPECIES, REMINDER_CATEGORIES, AI_TONES, ENTRY_TYPES } from './store.js';

function normalizeBaseUrl(url) {
  return String(url || '').trim().replace(/\/+$/, '');
}

export async function testConnection(ai) {
  const base = normalizeBaseUrl(ai.baseUrl);
  if (!base) return { ok: false, message: '请填写 API 地址' };
  if (!ai.apiKey) return { ok: false, message: '请填写 API Key' };
  const model = ai.model || 'gpt-4o-mini';
  try {
    const res = await fetch(`${base}/chat/completions`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${ai.apiKey}`,
      },
      body: JSON.stringify({
        model,
        messages: [{ role: 'user', content: '只回复两个字：正常' }],
        max_tokens: 16,
        temperature: 0.3,
      }),
    });
    if (!res.ok) {
      const text = await res.text().catch(() => '');
      return { ok: false, message: `请求失败（${res.status}）${text ? '：' + text.slice(0, 120) : ''}` };
    }
    const data = await res.json();
    if (data && data.choices && data.choices[0]) {
      return { ok: true, message: `连接成功 · ${model}` };
    }
    return { ok: false, message: '返回格式无法识别' };
  } catch (err) {
    return { ok: false, message: `网络错误：${err.message || err}（浏览器跨域限制可能需要代理地址）` };
  }
}

export async function chatOnce(ai, messages, { signal } = {}) {
  const base = normalizeBaseUrl(ai.baseUrl);
  const model = ai.model || 'gpt-4o-mini';
  const res = await fetch(`${base}/chat/completions`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${ai.apiKey}`,
    },
    body: JSON.stringify({
      model,
      messages,
      temperature: 0.7,
    }),
    signal,
  });
  if (!res.ok) {
    const text = await res.text().catch(() => '');
    throw new Error(`AI 请求失败（${res.status}）${text ? '：' + text.slice(0, 200) : ''}`);
  }
  const data = await res.json();
  const content = data?.choices?.[0]?.message?.content;
  if (!content) throw new Error('AI 返回为空');
  return content;
}

/* ---------- 上下文 ---------- */

function dateKeyOf(ts) {
  const d = new Date(ts);
  const p = (n) => String(n).padStart(2, '0');
  return `${d.getFullYear()}-${p(d.getMonth() + 1)}-${p(d.getDate())}`;
}

export function buildSystemPrompt(state) {
  const pet = state.pet;
  const speciesLabel = SPECIES[pet.species]?.label || pet.species;
  const toneHint = AI_TONES[state.ai?.tone]?.hint || AI_TONES.warm.hint;
  const lines = [
    `你是「同窝 Covey」里的宠物伙伴助手，名字叫 Pawly。你和用户一起生活，熟悉家里的宠物${pet.name}，像一个经常来往的朋友。`,
    '说话像真人：自然、简短、有温度。避免“根据记录显示”“综上所述”“希望对你有帮助”这类机器腔；不要用生硬的列表腔，除非用户要求详细。',
    '回答一般几句话说清，可以有一点个人感受，但不过度卖萌。建议要有依据（引用记录或常识），不确定就直说。不替用户做医疗诊断，涉及生病就建议就医。',
    `语气：${toneHint}。`,
    '',
    `宠物档案：名字「${pet.name}」，物种：${speciesLabel}${pet.breed ? '，品种：' + pet.breed : ''}${pet.birthday ? '，生日：' + pet.birthday : ''}${pet.weight ? '，体重：' + pet.weight + 'kg' : '，体重未知'}。`,
  ];

  // 最近 14 天每天的记录概况
  const stats = [];
  for (let i = 13; i >= 0; i--) {
    const d = new Date();
    d.setDate(d.getDate() - i);
    const key = dateKeyOf(d.getTime());
    const dayEntries = state.entries.filter((e) => dateKeyOf(new Date(e.ts)) === key);
    const p = (n) => String(n).padStart(2, '0');
    const label = `${p(d.getMonth() + 1)}-${p(d.getDate())}`;
    const summary = dayEntries.length
      ? [...new Set(dayEntries.map((e) => ENTRY_TYPES[e.type]?.label || e.type))].join('、')
      : '无';
    stats.push(`${label}：${dayEntries.length} 条（${summary}）`);
  }
  lines.push('', '近 14 天记录概况：', ...stats);

  // 最近记录
  const recent = state.entries.slice(0, 15).map((e) => {
    const t = new Date(e.ts);
    const p = (n) => String(n).padStart(2, '0');
    const time = `${p(t.getMonth() + 1)}-${p(t.getDate())} ${p(t.getHours())}:${p(t.getMinutes())}`;
    const kind = e.type === 'care' ? '照护' : e.type === 'photo' ? '照片' : e.type === 'spend' ? '花费' : e.type === 'health' ? '健康' : '日常';
    const extra = e.amount != null ? ` ¥${e.amount}` : '';
    return `- ${time} [${kind}] ${e.text || '（无文字）'}${extra}`;
  });
  if (recent.length) {
    lines.push('', '最近记录：', ...recent);
  } else {
    lines.push('', '最近还没有记录。');
  }

  const weights = state.weights.slice(-5).map((w) => `${w.date}: ${w.kg}kg`);
  if (weights.length) lines.push('', `体重记录（近几次）：${weights.join('；')}`);

  const reminders = state.reminders.filter((r) => !r.done).slice(0, 8)
    .map((r) => `- ${r.due} ${REMINDER_CATEGORIES[r.category] || '提醒'}：${r.title}`);
  if (reminders.length) lines.push('', '待办提醒：', ...reminders);

  lines.push('', '请基于以上真实记录回答。');
  return lines.join('\n');
}
