package com.bolerat.covey

import org.json.JSONArray
import org.json.JSONObject

/* ---------- 常量 ---------- */

val SPECIES = linkedMapOf("cat" to "猫", "dog" to "狗", "rabbit" to "兔子", "other" to "其他")
val SPECIES_EMOJI = mapOf("cat" to "🐱", "dog" to "🐶", "rabbit" to "🐰", "other" to "🐾")

// care 仅用于兼容旧版本数据，新版不再产生
val ENTRY_TYPES = linkedMapOf(
    "care" to "照护",
    "note" to "日常",
    "photo" to "照片",
    "spend" to "花费",
    "health" to "健康",
)

val JOURNAL_FILTERS = listOf(
    "all" to "全部", "photo" to "照片", "spend" to "花费", "health" to "健康", "note" to "日常",
)

val REMINDER_CATEGORIES = linkedMapOf(
    "vaccine" to "疫苗", "deworm" to "驱虫", "grooming" to "洗护", "medical" to "就诊", "custom" to "自定义",
)

data class AiPreset(val key: String, val label: String, val baseUrl: String, val model: String)
val AI_PROVIDERS = listOf(
    AiPreset("deepseek", "DeepSeek", "https://api.deepseek.com/v1", "deepseek-chat"),
    AiPreset("openai", "OpenAI", "https://api.openai.com/v1", "gpt-4o-mini"),
    AiPreset("glm", "智谱 GLM", "https://open.bigmodel.cn/api/paas/v4", "glm-4-flash"),
    AiPreset("qwen", "通义千问", "https://dashscope.aliyuncs.com/compatible-mode/v1", "qwen-plus"),
    AiPreset("custom", "自定义（OpenAI 兼容）", "", ""),
)

data class AiTone(val key: String, val label: String, val hint: String)
val AI_TONES = listOf(
    AiTone("warm", "温暖陪伴", "像家人一样自然关心，语气温和，不说教"),
    AiTone("lively", "活泼俏皮", "轻松幽默，可以偶尔用 emoji，但不过分"),
    AiTone("concise", "简洁利落", "直奔重点，少寒暄，先给答案"),
    AiTone("calm", "冷静专业", "条理清晰，先结论后依据，语气平稳"),
)

/* ---------- 数据模型 ---------- */

data class Pet(
    val name: String = "布丁",
    val species: String = "cat",
    val breed: String = "",
    val birthday: String = "",
    val weight: String = "",
)

data class Member(val id: String, val name: String, val role: String)

data class Entry(
    val id: String,
    val ts: Long,
    val type: String,
    val text: String,
    val photo: String? = null,
    val amount: Double? = null,
    val by: String = "me",
)

data class Reminder(
    val id: String,
    val title: String,
    val category: String = "custom",
    val due: String,
    val done: Boolean = false,
    val note: String = "",
)

data class WeightRecord(val id: String, val date: String, val kg: Double)

data class AIConfig(
    val provider: String = "deepseek",
    val baseUrl: String = "https://api.deepseek.com/v1",
    val apiKey: String = "",
    val model: String = "deepseek-chat",
    val tone: String = "warm",
) {
    val configured: Boolean get() = apiKey.isNotBlank() && baseUrl.isNotBlank()
}

data class ChatMessage(val role: String, val content: String, val ts: Long)

data class CoveyState(
    val version: Int = 1,
    val pet: Pet = Pet(),
    val activeMember: String = "me",
    val members: List<Member> = listOf(Member("me", "我", "owner")),
    val entries: List<Entry> = emptyList(),
    val reminders: List<Reminder> = emptyList(),
    val remindersEnabled: Boolean = true,
    val weights: List<WeightRecord> = emptyList(),
    val ai: AIConfig = AIConfig(),
    val chat: List<ChatMessage> = emptyList(),
)

/* ---------- JSON 编解码（字段名与网页版/iOS 版一致） ---------- */

fun CoveyState.toJson(): String {
    val root = JSONObject()
    root.put("version", version)

    root.put("pet", JSONObject().apply {
        put("name", pet.name); put("species", pet.species); put("breed", pet.breed)
        put("birthday", pet.birthday); put("weight", pet.weight)
    })
    root.put("activeMember", activeMember)
    root.put("members", JSONArray().apply {
        members.forEach { m -> put(JSONObject().apply { put("id", m.id); put("name", m.name); put("role", m.role) }) }
    })
    root.put("entries", JSONArray().apply {
        entries.forEach { e ->
            put(JSONObject().apply {
                put("id", e.id); put("ts", e.ts); put("type", e.type); put("text", e.text)
                e.photo?.let { put("photo", it) }
                e.amount?.let { put("amount", it) }
                put("by", e.by)
            })
        }
    })
    root.put("reminders", JSONArray().apply {
        reminders.forEach { r ->
            put(JSONObject().apply {
                put("id", r.id); put("title", r.title); put("category", r.category)
                put("due", r.due); put("done", r.done); put("note", r.note)
            })
        }
    })
    root.put("remindersEnabled", remindersEnabled)
    root.put("weights", JSONArray().apply {
        weights.forEach { w -> put(JSONObject().apply { put("id", w.id); put("date", w.date); put("kg", w.kg) }) }
    })
    root.put("ai", JSONObject().apply {
        put("provider", ai.provider); put("baseUrl", ai.baseUrl); put("apiKey", ai.apiKey)
        put("model", ai.model); put("tone", ai.tone)
    })
    root.put("chat", JSONArray().apply {
        chat.forEach { c -> put(JSONObject().apply { put("role", c.role); put("content", c.content); put("ts", c.ts) }) }
    })
    return root.toString()
}

fun coveyStateFromJson(text: String): CoveyState? {
    return try {
        val root = JSONObject(text)
        if (!root.has("pet") || root.isNull("pet")) return null
        val def = CoveyState()

        val petObj = root.optJSONObject("pet") ?: JSONObject()
        val pet = Pet(
            name = petObj.optString("name", def.pet.name),
            species = petObj.optString("species", def.pet.species),
            breed = petObj.optString("breed", ""),
            birthday = petObj.optString("birthday", ""),
            weight = petObj.optString("weight", ""),
        )

        val membersArr = root.optJSONArray("members")
        val members = if (membersArr != null && membersArr.length() > 0) {
            (0 until membersArr.length()).map { i ->
                val m = membersArr.getJSONObject(i)
                Member(m.optString("id"), m.optString("name"), m.optString("role", "viewer"))
            }
        } else def.members

        val entriesArr = root.optJSONArray("entries")
        val entries = if (entriesArr != null) {
            (0 until entriesArr.length()).mapNotNull { i ->
                val e = entriesArr.optJSONObject(i) ?: return@mapNotNull null
                Entry(
                    id = e.optString("id", uid("e")),
                    ts = e.optLong("ts", System.currentTimeMillis()),
                    type = e.optString("type", "note"),
                    text = e.optString("text", ""),
                    photo = if (e.isNull("photo")) null else e.optString("photo").ifBlank { null },
                    amount = if (e.isNull("amount")) null else e.optDouble("amount", Double.NaN).takeIf { !it.isNaN() },
                    by = e.optString("by", "me"),
                )
            }
        } else emptyList()

        val remindersArr = root.optJSONArray("reminders")
        val reminders = if (remindersArr != null) {
            (0 until remindersArr.length()).mapNotNull { i ->
                val r = remindersArr.optJSONObject(i) ?: return@mapNotNull null
                Reminder(
                    id = r.optString("id", uid("r")),
                    title = r.optString("title", ""),
                    category = r.optString("category", "custom"),
                    due = r.optString("due", ""),
                    done = r.optBoolean("done", false),
                    note = r.optString("note", ""),
                )
            }
        } else emptyList()

        val weightsArr = root.optJSONArray("weights")
        val weights = if (weightsArr != null) {
            (0 until weightsArr.length()).mapNotNull { i ->
                val w = weightsArr.optJSONObject(i) ?: return@mapNotNull null
                WeightRecord(w.optString("id", uid("w")), w.optString("date", ""), w.optDouble("kg", 0.0))
            }
        } else emptyList()

        val aiObj = root.optJSONObject("ai") ?: JSONObject()
        val ai = AIConfig(
            provider = aiObj.optString("provider", def.ai.provider),
            baseUrl = aiObj.optString("baseUrl", def.ai.baseUrl),
            apiKey = aiObj.optString("apiKey", ""),
            model = aiObj.optString("model", def.ai.model),
            tone = aiObj.optString("tone", def.ai.tone),
        )

        val chatArr = root.optJSONArray("chat")
        val chat = if (chatArr != null) {
            (0 until chatArr.length()).mapNotNull { i ->
                val c = chatArr.optJSONObject(i) ?: return@mapNotNull null
                ChatMessage(c.optString("role", "user"), c.optString("content", ""), c.optLong("ts", System.currentTimeMillis()))
            }.takeLast(50)
        } else emptyList()

        CoveyState(
            pet = pet,
            activeMember = root.optString("activeMember", "me"),
            members = members,
            entries = entries.sortedByDescending { it.ts },
            reminders = reminders,
            remindersEnabled = root.optBoolean("remindersEnabled", true),
            weights = weights.sortedBy { it.date },
            ai = ai,
            chat = chat,
        )
    } catch (e: Exception) {
        null
    }
}
