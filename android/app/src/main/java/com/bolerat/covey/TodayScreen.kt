package com.bolerat.covey

import android.net.Uri
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.PickVisualMediaRequest
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.window.Dialog
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import androidx.core.content.FileProvider
import java.io.File
import java.time.LocalDate
import java.time.format.DateTimeFormatter

private fun todayHeaderText(): String {
    val now = LocalDate.now()
    val week = listOf("周日", "周一", "周二", "周三", "周四", "周五", "周六")
    return "${now.monthValue}月${now.dayOfMonth}日 ${week[now.dayOfWeek.value % 7]}"
}

private fun ruleInsight(state: CoveyState): String {
    val parts = mutableListOf<String>()
    val weekCount = weekEntryCount(state)
    val due = remindersDueSoon(state, 7).size
    val daysW = daysSinceWeight(state)
    if (weekCount > 0) parts.add("这周记了 $weekCount 条日常。")
    if (due > 0) parts.add("$due 件提醒在 7 天内到期。")
    if (daysW == null) parts.add("还没有体重记录，记一次可以留意变化。")
    else if (daysW > 30) parts.add("体重已经 ${daysW} 天没记录了。")
    if (parts.isEmpty()) parts.add("记下今天的日常，我就能给出更有依据的建议。")
    return parts.joinToString("")
}

@Composable
fun TodayScreen(onAskAi: (String) -> Unit) {
    val state = Store.state
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    val pet = state.pet

    var showNote by remember { mutableStateOf(false) }
    var showReminder by remember { mutableStateOf(false) }
    var photoChooser by remember { mutableStateOf(false) }
    var photoBase64 by remember { mutableStateOf<String?>(null) }
    var detailEntry by remember { mutableStateOf<Entry?>(null) }
    var cameraFile by remember { mutableStateOf<File?>(null) }

    val todayCount = state.entries.count { dateKeyOf(it.ts) == todayKey() }
    val streak = recordStreak(state)
    val weekCount = weekEntryCount(state)
    val reminders = remindersDueSoon(state, 7)
    val goal = 3
    val heroWeight = lastWeight(state)?.kg?.toString() ?: pet.weight.ifBlank { null }
    val age = ageText(pet.birthday)
    val tags = listOf(SPECIES[pet.species] ?: "其他", pet.breed, age).filter { it.isNotBlank() }

    fun decodeUri(uri: Uri) {
        scope.launch {
            val b64 = withContext(Dispatchers.IO) {
                try {
                    context.contentResolver.openInputStream(uri)?.use { stream ->
                        android.graphics.BitmapFactory.decodeStream(stream)?.let { bitmapToBase64(it) }
                    }
                } catch (e: Exception) { null }
            }
            if (b64 != null) photoBase64 = b64 else toast(context, "读取照片失败")
        }
    }

    val galleryLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.PickVisualMedia(),
    ) { uri -> uri?.let { decodeUri(it) } }

    val cameraLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.TakePicture(),
    ) { ok ->
        if (ok) cameraFile?.let { file ->
            scope.launch {
                val b64 = withContext(Dispatchers.IO) {
                    try { android.graphics.BitmapFactory.decodeFile(file.absolutePath)?.let { bitmapToBase64(it) } }
                    catch (e: Exception) { null }
                }
                if (b64 != null) photoBase64 = b64 else toast(context, "读取照片失败")
            }
        }
    }

    fun launchCamera() {
        val dir = File(context.cacheDir, "photos").apply { mkdirs() }
        val file = File(dir, "covey_${System.currentTimeMillis()}.jpg")
        file.createNewFile()
        cameraFile = file
        val uri = FileProvider.getUriForFile(context, context.packageName + ".fileprovider", file)
        cameraLauncher.launch(uri)
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(horizontal = 16.dp),
    ) {
        Spacer(Modifier.height(12.dp))
        Text(todayHeaderText(), style = MaterialTheme.typography.titleMedium, color = CoveyMuted)
        Spacer(Modifier.height(10.dp))

        // 宠物名片
        CoveyCard {
            Row(verticalAlignment = Alignment.CenterVertically) {
                PetAvatar(pet.species, diameter = 84.dp, progress = (todayCount.toFloat() / goal).coerceAtMost(1f))
                Spacer(Modifier.width(16.dp))
                Column(modifier = Modifier.weight(1f)) {
                    Text(pet.name, style = MaterialTheme.typography.headlineSmall, fontWeight = FontWeight.Bold, color = CoveyInk)
                    if (tags.isNotEmpty()) {
                        Spacer(Modifier.height(4.dp))
                        Text(tags.joinToString(" · "), fontSize = 13.sp, color = CoveyMuted)
                    }
                    Spacer(Modifier.height(8.dp))
                    Row(horizontalArrangement = Arrangement.spacedBy(14.dp)) {
                        HeroStat("🔥", "$streak", "连续记录")
                        HeroStat("📖", "$weekCount", "近 7 天")
                        HeroStat("⚖️", heroWeight ?: "—", "体重${heroWeight?.let { "kg" } ?: ""}")
                    }
                }
            }
        }
        Spacer(Modifier.height(12.dp))

        // 快捷操作
        Row(horizontalArrangement = Arrangement.spacedBy(10.dp), modifier = Modifier.fillMaxWidth()) {
            QuickAction("📷", "拍照", Modifier.weight(1f)) {
                photoChooser = true
            }
            QuickAction("📝", "记一笔", Modifier.weight(1f)) { showNote = true }
            QuickAction("✨", "问 Pawly", Modifier.weight(1f)) {
                onAskAi("请根据我家宠物${pet.name}最近的记录和待办提醒，给我 3 条简短、可执行的建议。")
            }
        }
        Spacer(Modifier.height(12.dp))

        // 提醒
        if (state.remindersEnabled) {
            CoveyCard {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text("提醒", style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold, color = CoveyInk)
                    Spacer(Modifier.weight(1f))
                    TextButton(onClick = { showReminder = true }) { Text("+ 新建", color = CoveyAccent) }
                }
                if (reminders.isEmpty()) {
                    Text("近期没有待办提醒，疫苗、驱虫、洗护都可以记在这里", fontSize = 13.sp, color = CoveyMuted)
                } else {
                    reminders.take(3).forEach { rwd ->
                        val r = rwd.reminder
                        Row(
                            modifier = Modifier.fillMaxWidth().padding(vertical = 6.dp),
                            verticalAlignment = Alignment.CenterVertically,
                        ) {
                            Column(modifier = Modifier.weight(1f)) {
                                Text(
                                    r.title, fontSize = 14.sp, color = if (rwd.overdue) CoveyDanger else CoveyInk,
                                    fontWeight = FontWeight.Medium,
                                )
                                Text(
                                    "${REMINDER_CATEGORIES[r.category] ?: "提醒"}${if (r.note.isNotBlank()) " · ${r.note}" else ""}",
                                    fontSize = 12.sp, color = CoveyMuted,
                                )
                            }
                            val dueText = when {
                                rwd.overdue -> "已过期"
                                r.due == todayKey() -> "今天"
                                else -> try {
                                    val d = LocalDate.parse(r.due)
                                    "${d.monthValue}月${d.dayOfMonth}日"
                                } catch (e: Exception) { r.due }
                            }
                            Text(dueText, fontSize = 12.sp, color = CoveyMuted)
                            TextButton(onClick = { Store.setReminderDone(r.id, true) }) { Text("完成", color = CoveySage, fontSize = 12.sp) }
                            TextButton(onClick = { Store.deleteReminder(r.id) }) { Text("删", color = CoveyMuted, fontSize = 12.sp) }
                        }
                    }
                }
            }
            Spacer(Modifier.height(12.dp))
        }

        // Pawly 观察
        CoveyCard {
            Row(verticalAlignment = Alignment.Top) {
                Text("✨", fontSize = 20.sp)
                Spacer(Modifier.width(8.dp))
                Column(modifier = Modifier.weight(1f)) {
                    Text("Pawly 的观察", style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold, color = CoveyInk)
                    Spacer(Modifier.height(4.dp))
                    Text(ruleInsight(state), fontSize = 13.sp, color = CoveyMuted)
                }
            }
            Spacer(Modifier.height(10.dp))
            if (!state.ai.configured) {
                Text("配置 AI 后可以让 Pawly 给出更有依据的建议", fontSize = 12.sp, color = CoveyMuted)
            }
            Button(
                onClick = { onAskAi("请根据我家宠物${pet.name}最近的记录和待办提醒，给我 3 条简短、可执行的建议。") },
                modifier = Modifier.fillMaxWidth(), shape = RoundedCornerShape(12.dp),
                colors = ButtonDefaults.buttonColors(containerColor = CoveyAccentSoft, contentColor = CoveyAccent),
            ) { Text("让 AI 分析一下") }
        }
        Spacer(Modifier.height(12.dp))

        // 最近记录
        SectionHeader("最近记录")
        val recent = state.entries.take(3)
        if (recent.isEmpty()) {
            CoveyCard { EmptyState("记一笔或拍照后会出现在这里") }
        } else {
            CoveyCard {
                recent.forEach { e -> EntryRow(e, onClick = { detailEntry = e }, state = state) }
            }
        }
        Spacer(Modifier.height(24.dp))
    }

    if (showNote) {
        NoteFormDialog(onDismiss = { showNote = false }) { type, text, amount ->
            Store.addEntry(type, text, amount = amount)
            showNote = false
            toast(context, "已记录")
        }
    }

    photoBase64?.let { b64 ->
        PhotoCaptionDialog(photoBase64 = b64, onDismiss = { photoBase64 = null }) { caption ->
            Store.addEntry("photo", caption, photo = b64)
            photoBase64 = null
            toast(context, "已记录")
        }
    }

    if (photoChooser) {
        Dialog(onDismissRequest = { photoChooser = false }) {
            Surface(shape = RoundedCornerShape(20.dp), color = CoveyCard) {
                Column(modifier = Modifier.padding(20.dp)) {
                    Text("记录照片", fontWeight = FontWeight.Bold, color = CoveyInk)
                    Spacer(Modifier.height(14.dp))
                    PhotoChoiceButton("📷 拍一张", onClick = { photoChooser = false; launchCamera() })
                    Spacer(Modifier.height(10.dp))
                    PhotoChoiceButton("🖼 从相册选", onClick = {
                        photoChooser = false
                        galleryLauncher.launch(PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly))
                    })
                    Spacer(Modifier.height(10.dp))
                    TextButton(onClick = { photoChooser = false }, modifier = Modifier.align(Alignment.End)) {
                        Text("取消", color = CoveyMuted)
                    }
                }
            }
        }
    }

    if (showReminder) {
        ReminderFormDialog(onDismiss = { showReminder = false }) { title, category, due, note ->
            Store.addReminder(title, category, due, note)
            showReminder = false
            toast(context, "提醒已创建")
        }
    }

    detailEntry?.let { e ->
        EntryDetailDialog(entry = e, state = state, onDismiss = { detailEntry = null }) {
            Store.deleteEntry(e.id)
            detailEntry = null
        }
    }
}

@Composable
private fun HeroStat(emoji: String, value: String, label: String) {
    Column {
        Text("$emoji $value", fontSize = 15.sp, fontWeight = FontWeight.Bold, color = CoveyInk)
        Text(label, fontSize = 11.sp, color = CoveyMuted)
    }
}

@Composable
private fun QuickAction(emoji: String, label: String, modifier: Modifier, onClick: () -> Unit) {
    Surface(
        onClick = onClick, modifier = modifier,
        shape = RoundedCornerShape(16.dp), color = CoveyCard,
        border = androidx.compose.foundation.BorderStroke(1.dp, CoveyLine),
    ) {
        Column(
            modifier = Modifier.padding(vertical = 14.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Text(emoji, fontSize = 24.sp)
            Spacer(Modifier.height(4.dp))
            Text(label, fontSize = 13.sp, color = CoveyInk)
        }
    }
}

@Composable
private fun PhotoChoiceButton(text: String, onClick: () -> Unit) {
    Surface(
        onClick = onClick, modifier = Modifier.fillMaxWidth(),
        shape = RoundedCornerShape(12.dp), color = CoveyAccentSoft,
    ) {
        Text(text, modifier = Modifier.padding(vertical = 12.dp), color = CoveyAccent, fontWeight = FontWeight.Medium)
    }
}
