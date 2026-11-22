package com.bolerat.covey

import android.content.Context
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.util.UUID
import kotlin.math.floor

/* ---------- 时间与 ID 工具 ---------- */

fun uid(prefix: String): String = prefix + UUID.randomUUID().toString().replace("-", "").take(10)

private val zone: ZoneId get() = ZoneId.systemDefault()

fun todayKey(): String = LocalDate.now(zone).format(DateTimeFormatter.ISO_LOCAL_DATE)

fun dateKeyOf(ts: Long): String =
    Instant.ofEpochMilli(ts).atZone(zone).toLocalDate().format(DateTimeFormatter.ISO_LOCAL_DATE)

fun timeKeyOf(ts: Long): String {
    val t = Instant.ofEpochMilli(ts).atZone(zone).toLocalTime()
    return "%02d:%02d".format(t.hour, t.minute)
}

fun fmtDateCN(dateStr: String): String {
    return try {
        val d = LocalDate.parse(dateStr)
        val today = LocalDate.now(zone)
        val yesterday = today.minusDays(1)
        when (d) {
            today -> "今天"
            yesterday -> "昨天"
            else -> {
                val week = listOf("周日", "周一", "周二", "周三", "周四", "周五", "周六")
                "${d.monthValue}月${d.dayOfMonth}日 ${week[d.dayOfWeek.value % 7]}"
            }
        }
    } catch (e: Exception) { dateStr }
}

fun fmtFullDateTime(ts: Long): String {
    val d = Instant.ofEpochMilli(ts).atZone(zone)
    return "${d.year}年${d.monthValue}月${d.dayOfMonth}日 ${timeKeyOf(ts)}"
}

fun ageText(birthday: String): String {
    if (birthday.isBlank()) return ""
    return try {
        val b = LocalDate.parse(birthday)
        val today = LocalDate.now(zone)
        var years = today.year - b.year
        var months = today.monthValue - b.monthValue
        if (today.dayOfMonth < b.dayOfMonth) months -= 1
        if (months < 0) { years -= 1; months += 12 }
        when {
            years >= 1 -> if (months > 0) "${years}岁${months}个月" else "${years}岁"
            months >= 1 -> "${months}个月"
            else -> "不到 1 个月"
        }
    } catch (e: Exception) { "" }
}

fun memberName(state: CoveyState, id: String): String =
    state.members.firstOrNull { it.id == id }?.name ?: "我"

/* ---------- 统计 ---------- */

fun entriesSince(state: CoveyState, days: Int): List<Entry> {
    val since = System.currentTimeMillis() - days * 86400000L
    return state.entries.filter { it.ts >= since }
}

fun weekEntryCount(state: CoveyState): Int = entriesSince(state, 7).size

// 连续记录天数：今天或昨天有记录就起算
fun recordStreak(state: CoveyState): Int {
    var streak = 0
    var cursor = LocalDate.now(zone)
    val hasToday = state.entries.any { dateKeyOf(it.ts) == todayKey() }
    if (!hasToday) cursor = cursor.minusDays(1)
    while (state.entries.any { dateKeyOf(it.ts) == cursor.format(DateTimeFormatter.ISO_LOCAL_DATE) }) {
        streak += 1
        cursor = cursor.minusDays(1)
    }
    return streak
}

fun remindersDueSoon(state: CoveyState, days: Int = 7): List<ReminderWithDue> {
    if (!state.remindersEnabled) return emptyList()
    val today = LocalDate.now(zone)
    val limit = today.plusDays(days.toLong())
    return state.reminders.filter { !it.done }.mapNotNull { r ->
        val due = try { LocalDate.parse(r.due) } catch (e: Exception) { return@mapNotNull null }
        if (!due.isAfter(limit)) ReminderWithDue(r, due.isBefore(today)) else null
    }.sortedBy { it.reminder.due }
}

data class ReminderWithDue(val reminder: Reminder, val overdue: Boolean)

fun lastWeight(state: CoveyState): WeightRecord? = state.weights.maxByOrNull { it.date }

fun daysSinceWeight(state: CoveyState): Int? {
    val last = lastWeight(state) ?: return null
    return try {
        val d = LocalDate.parse(last.date)
        ChronoUnitDays(d, LocalDate.now(zone))
    } catch (e: Exception) { null }
}

private fun ChronoUnitDays(from: LocalDate, to: LocalDate): Int =
    java.time.temporal.ChronoUnit.DAYS.between(from, to).toInt()

/* ---------- 全局状态存储 ---------- */

object Store {
    private lateinit var prefs: android.content.SharedPreferences

    var state by mutableStateOf(CoveyState())
        private set

    fun init(context: Context) {
        prefs = context.applicationContext.getSharedPreferences("covey", Context.MODE_PRIVATE)
        state = load()
    }

    private fun load(): CoveyState {
        val raw = prefs.getString("covey-state-v1", null) ?: return CoveyState()
        return coveyStateFromJson(raw) ?: CoveyState()
    }

    private fun persist() {
        prefs.edit().putString("covey-state-v1", state.toJson()).apply()
    }

    fun update(block: (CoveyState) -> CoveyState) {
        state = block(state)
        persist()
    }

    fun replaceAll(newState: CoveyState) {
        state = newState
        persist()
    }

    fun reset() {
        state = CoveyState()
        persist()
    }

    /* --- 记录 --- */
    fun addEntry(type: String, text: String, photo: String? = null, amount: Double? = null) {
        val entry = Entry(
            id = uid("e"), ts = System.currentTimeMillis(), type = type, text = text.trim(),
            photo = photo, amount = amount, by = state.activeMember,
        )
        update { it.copy(entries = listOf(entry) + it.entries) }
    }

    fun deleteEntry(id: String) = update { it.copy(entries = it.entries.filterNot { it.id == id }) }

    /* --- 提醒 --- */
    fun addReminder(title: String, category: String, due: String, note: String) {
        val r = Reminder(uid("r"), title.trim(), category, due, note = note.trim())
        update { it.copy(reminders = listOf(r) + it.reminders) }
    }

    fun setReminderDone(id: String, done: Boolean) =
        update { s -> s.copy(reminders = s.reminders.map { if (it.id == id) it.copy(done = done) else it }) }

    fun deleteReminder(id: String) = update { it.copy(reminders = it.reminders.filterNot { it.id == id }) }

    /* --- 体重 --- */
    fun addWeight(date: String, kg: Double) {
        val w = WeightRecord(uid("w"), date, kg)
        update { s ->
            s.copy(
                weights = (s.weights.filter { it.date != date } + w).sortedBy { it.date },
                pet = s.pet.copy(weight = formatKg(kg)),
            )
        }
    }

    private fun formatKg(kg: Double): String =
        if (kg == floor(kg)) kg.toLong().toString() else kg.toString()

    /* --- 档案与成员 --- */
    fun savePet(name: String, species: String, breed: String, birthday: String, weight: String) {
        update { it.copy(pet = Pet(name.trim(), species, breed.trim(), birthday, weight.trim())) }
    }

    fun addMember(name: String, role: String) {
        val m = Member(uid("m"), name.trim(), role)
        update { it.copy(members = it.members + m) }
    }

    fun switchMember(id: String) = update { it.copy(activeMember = id) }

    /* --- AI 配置与对话 --- */
    fun saveAIConfig(provider: String, baseUrl: String, apiKey: String, model: String, tone: String) {
        update { it.copy(ai = AIConfig(provider, baseUrl.trim(), apiKey.trim(), model.trim(), tone)) }
    }

    fun appendChat(role: String, content: String) {
        val msg = ChatMessage(role, content, System.currentTimeMillis())
        update { it.copy(chat = (it.chat + msg).takeLast(100)) }
    }
}
