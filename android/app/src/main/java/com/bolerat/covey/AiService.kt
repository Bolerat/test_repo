package com.bolerat.covey

import org.json.JSONArray
import org.json.JSONObject
import java.io.BufferedReader
import java.io.InputStreamReader
import java.io.OutputStreamWriter
import java.net.HttpURLConnection
import java.net.URL

/* ---------- OpenAI 兼容 chat/completions ---------- */

private fun normalizeBaseUrl(url: String): String = url.trim().trimEnd('/')

private fun postChatCompletions(ai: AIConfig, messages: JSONArray, maxTokens: Int? = null): String {
    val base = normalizeBaseUrl(ai.baseUrl)
    require(base.isNotEmpty()) { "请填写 API 地址" }
    require(ai.apiKey.isNotEmpty()) { "请填写 API Key" }
    val model = ai.model.ifBlank { "gpt-4o-mini" }

    val payload = JSONObject().apply {
        put("model", model)
        put("messages", messages)
        put("temperature", 0.7)
        maxTokens?.let { put("max_tokens", it) }
    }

    val conn = (URL("$base/chat/completions").openConnection() as HttpURLConnection).apply {
        requestMethod = "POST"
        connectTimeout = 30000
        readTimeout = 60000
        doOutput = true
        setRequestProperty("Content-Type", "application/json")
        setRequestProperty("Authorization", "Bearer ${ai.apiKey}")
    }

    try {
        OutputStreamWriter(conn.outputStream).use { it.write(payload.toString()) }
        val code = conn.responseCode
        val stream = if (code in 200..299) conn.inputStream else conn.errorStream
        val text = stream?.let { s ->
            BufferedReader(InputStreamReader(s, Charsets.UTF_8)).use { it.readText() }
        } ?: ""
        if (code !in 200..299) {
            throw Exception("AI 请求失败（$code）" + if (text.isNotBlank()) "：${text.take(200)}" else "")
        }
        val data = JSONObject(text)
        val choices = data.optJSONArray("choices")
        val content = choices?.optJSONObject(0)?.optJSONObject("message")?.optString("content")
        if (content.isNullOrBlank()) throw Exception("AI 返回为空")
        return content
    } finally {
        conn.disconnect()
    }
}

data class ChatTurn(val role: String, val content: String)

fun testAiConnection(ai: AIConfig): String {
    val messages = JSONArray().apply {
        put(JSONObject().apply {
            put("role", "user"); put("content", "只回复两个字：正常")
        })
    }
    return try {
        postChatCompletions(ai, messages, maxTokens = 16)
        "连接成功 · ${ai.model.ifBlank { "gpt-4o-mini" }}"
    } catch (e: Exception) {
        "连接失败：${e.message ?: e}"
    }
}

suspend fun chatWithAi(ai: AIConfig, turns: List<ChatTurn>): String =
    kotlinx.coroutines.withContext(kotlinx.coroutines.Dispatchers.IO) {
        val messages = JSONArray()
        turns.forEach { t ->
            messages.put(JSONObject().apply { put("role", t.role); put("content", t.content) })
        }
        postChatCompletions(ai, messages)
    }

/* ---------- 系统提示词 ---------- */

fun buildSystemPrompt(state: CoveyState): String {
    val pet = state.pet
    val speciesLabel = SPECIES[pet.species] ?: pet.species
    val toneHint = AI_TONES.firstOrNull { it.key == state.ai.tone }?.hint ?: AI_TONES.first().hint

    val lines = mutableListOf(
        "你是「同窝 Covey」里的宠物伙伴助手，名字叫 Pawly。你和用户一起生活，熟悉家里的宠物${pet.name}，像一个经常来往的朋友。",
        "说话像真人：自然、简短、有温度。避免“根据记录显示”“综上所述”“希望对你有帮助”这类机器腔；不要用生硬的列表腔，除非用户要求详细。",
        "回答一般几句话说清，可以有一点个人感受，但不过度卖萌。建议要有依据（引用记录或常识），不确定就直说。不替用户做医疗诊断，涉及生病就建议就医。",
        "语气：${toneHint}。",
        "",
        "宠物档案：名字「${pet.name}」，物种：${speciesLabel}" +
            (if (pet.breed.isNotBlank()) "，品种：${pet.breed}" else "") +
            (if (pet.birthday.isNotBlank()) "，生日：${pet.birthday}" else "") +
            (if (pet.weight.isNotBlank()) "，体重：${pet.weight}kg" else "，体重未知") + "。",
    )

    // 近 14 天每天的记录概况
    val stats = mutableListOf<String>()
    val today = java.time.LocalDate.now()
    for (i in 13 downTo 0) {
        val d = today.minusDays(i.toLong())
        val key = d.format(java.time.format.DateTimeFormatter.ISO_LOCAL_DATE)
        val dayEntries = state.entries.filter { dateKeyOf(it.ts) == key }
        val label = "%02d-%02d".format(d.monthValue, d.dayOfMonth)
        val summary = dayEntries.map { ENTRY_TYPES[it.type] ?: it.type }.distinct().joinToString("、").ifBlank { "无" }
        stats.add("$label：${dayEntries.size} 条（$summary）")
    }
    lines.add("")
    lines.add("近 14 天记录概况：")
    lines.addAll(stats)

    // 最近记录
    val recent = state.entries.take(15).map { e ->
        val t = java.time.Instant.ofEpochMilli(e.ts).atZone(java.time.ZoneId.systemDefault())
        val time = "%02d-%02d %02d:%02d".format(t.monthValue, t.dayOfMonth, t.hour, t.minute)
        val kind = ENTRY_TYPES[e.type] ?: e.type
        val extra = e.amount?.let { " ¥%.0f".format(it) } ?: ""
        "- $time [$kind] ${e.text.ifBlank { "（无文字）" }}$extra"
    }
    if (recent.isNotEmpty()) {
        lines.add("")
        lines.add("最近记录：")
        lines.addAll(recent)
    } else {
        lines.add("")
        lines.add("最近还没有记录。")
    }

    val weights = state.weights.takeLast(5).joinToString("；") { "${it.date}: ${it.kg}kg" }
    if (weights.isNotBlank()) lines.add("") ; if (weights.isNotBlank()) lines.add("体重记录（近几次）：$weights")

    val reminders = state.reminders.filter { !it.done }.take(8)
        .joinToString("\n") { "- ${it.due} ${REMINDER_CATEGORIES[it.category] ?: "提醒"}：${it.title}" }
    if (reminders.isNotBlank()) {
        lines.add("")
        lines.add("待办提醒：")
        lines.add(reminders)
    }

    lines.add("")
    lines.add("请基于以上真实记录回答。")
    return lines.joinToString("\n")
}
