package com.bolerat.covey

import androidx.compose.foundation.Image
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.window.Dialog
import android.widget.Toast
import java.time.LocalDate

val ChipIdle = Color(0xFFF1EAE2)

fun toast(context: android.content.Context, msg: String) {
    Toast.makeText(context, msg, Toast.LENGTH_SHORT).show()
}

private fun isValidDate(s: String): Boolean = try { LocalDate.parse(s.trim()); true } catch (e: Exception) { false }

/* ---------- 基础对话框 ---------- */

@Composable
fun FormDialog(
    title: String,
    onDismiss: () -> Unit,
    onConfirm: () -> Unit,
    confirmText: String = "保存",
    content: @Composable ColumnScope.() -> Unit,
) {
    Dialog(onDismissRequest = onDismiss) {
        Surface(shape = RoundedCornerShape(20.dp), color = CoveyCard, modifier = Modifier.fillMaxWidth()) {
            Column(modifier = Modifier.padding(20.dp).verticalScroll(rememberScrollState())) {
                Text(title, style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold, color = CoveyInk)
                Spacer(Modifier.height(14.dp))
                content()
                Spacer(Modifier.height(18.dp))
                Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.End) {
                    TextButton(onClick = onDismiss) { Text("取消", color = CoveyMuted) }
                    Spacer(Modifier.width(8.dp))
                    Button(onClick = onConfirm, shape = RoundedCornerShape(12.dp)) { Text(confirmText) }
                }
            }
        }
    }
}

@Composable
fun ConfirmDialog(message: String, confirmText: String = "确定", onDismiss: () -> Unit, onConfirm: () -> Unit) {
    Dialog(onDismissRequest = onDismiss) {
        Surface(shape = RoundedCornerShape(20.dp), color = CoveyCard) {
            Column(modifier = Modifier.padding(20.dp)) {
                Text(message, color = CoveyInk, fontSize = 15.sp)
                Spacer(Modifier.height(18.dp))
                Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.End) {
                    TextButton(onClick = onDismiss) { Text("取消", color = CoveyMuted) }
                    Spacer(Modifier.width(8.dp))
                    Button(
                        onClick = onConfirm, shape = RoundedCornerShape(12.dp),
                        colors = ButtonDefaults.buttonColors(containerColor = CoveyDanger),
                    ) { Text(confirmText) }
                }
            }
        }
    }
}

/* ---------- 选择控件 ---------- */

@Composable
fun SelectField(label: String, options: List<Pair<String, String>>, value: String, onSelect: (String) -> Unit) {
    var expanded by remember { mutableStateOf(false) }
    val current = options.firstOrNull { it.first == value }?.second ?: value
    Column(modifier = Modifier.fillMaxWidth()) {
        Text(label, fontSize = 12.sp, color = CoveyMuted)
        Spacer(Modifier.height(4.dp))
        Box {
            OutlinedButton(onClick = { expanded = true }, modifier = Modifier.fillMaxWidth(), shape = RoundedCornerShape(12.dp)) {
                Text(current, modifier = Modifier.weight(1f), color = CoveyInk)
                Text("▾", color = CoveyMuted)
            }
            DropdownMenu(expanded = expanded, onDismissRequest = { expanded = false }) {
                options.forEach { (k, v) ->
                    DropdownMenuItem(text = { Text(v) }, onClick = { onSelect(k); expanded = false })
                }
            }
        }
    }
}

@Composable
fun ChipRow(options: List<Pair<String, String>>, value: String, onSelect: (String) -> Unit) {
    Row(horizontalArrangement = Arrangement.spacedBy(8.dp), modifier = Modifier.fillMaxWidth()) {
        options.forEach { (k, v) ->
            val selected = value == k
            Surface(
                onClick = { onSelect(k) },
                shape = RoundedCornerShape(10.dp),
                color = if (selected) CoveyAccentSoft else ChipIdle,
                modifier = Modifier.weight(1f),
            ) {
                Text(
                    v,
                    modifier = Modifier.padding(vertical = 9.dp),
                    textAlign = TextAlign.Center,
                    color = if (selected) CoveyAccent else CoveyMuted,
                    fontSize = 13.sp,
                    fontWeight = if (selected) FontWeight.Bold else FontWeight.Normal,
                )
            }
        }
    }
}

/* ---------- 记一笔 ---------- */

@Composable
fun NoteFormDialog(onDismiss: () -> Unit, onSave: (type: String, text: String, amount: Double?) -> Unit) {
    val context = LocalContext.current
    var type by remember { mutableStateOf("note") }
    var text by remember { mutableStateOf("") }
    var amount by remember { mutableStateOf("") }

    FormDialog("记一笔", onDismiss = onDismiss, onConfirm = {
        val amt = amount.toDoubleOrNull()
        when {
            text.isBlank() && amt == null -> toast(context, "写点内容吧")
            type == "spend" && (amt == null || amt <= 0) -> toast(context, "请填写金额")
            else -> onSave(type, text, if (type == "spend") amt else null)
        }
    }) {
        ChipRow(listOf("note" to "日常", "spend" to "花费", "health" to "健康"), type) { type = it }
        Spacer(Modifier.height(12.dp))
        OutlinedTextField(
            value = text, onValueChange = { text = it },
            label = { Text(if (type == "health") "比如：今天打了个喷嚏" else "写点什么") },
            modifier = Modifier.fillMaxWidth(), minLines = 2, maxLines = 5,
        )
        if (type == "spend") {
            Spacer(Modifier.height(10.dp))
            OutlinedTextField(
                value = amount, onValueChange = { amount = it.filter { c -> c.isDigit() || c == '.' } },
                label = { Text("金额（元）") }, modifier = Modifier.fillMaxWidth(), singleLine = true,
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Decimal),
            )
        }
    }
}

/* ---------- 照片记录 ---------- */

@Composable
fun PhotoCaptionDialog(photoBase64: String, onDismiss: () -> Unit, onSave: (caption: String) -> Unit) {
    var caption by remember { mutableStateOf("") }
    val bitmap = remember(photoBase64) { base64ToBitmap(photoBase64) }
    FormDialog("照片记录", onDismiss = onDismiss, onConfirm = { onSave(caption) }) {
        if (bitmap != null) {
            Image(
                bitmap = bitmap.asImageBitmap(), contentDescription = "预览",
                modifier = Modifier.fillMaxWidth().aspectRatio(4f / 3f).clip(RoundedCornerShape(12.dp)),
                contentScale = ContentScale.Crop,
            )
            Spacer(Modifier.height(10.dp))
        }
        OutlinedTextField(
            value = caption, onValueChange = { caption = it },
            label = { Text("写点什么（可不填）") }, modifier = Modifier.fillMaxWidth(),
        )
    }
}

/* ---------- 提醒 ---------- */

@Composable
fun ReminderFormDialog(onDismiss: () -> Unit, onSave: (title: String, category: String, due: String, note: String) -> Unit) {
    val context = LocalContext.current
    var title by remember { mutableStateOf("") }
    var category by remember { mutableStateOf("vaccine") }
    var due by remember { mutableStateOf(todayKey()) }
    var note by remember { mutableStateOf("") }

    FormDialog("新建提醒", onDismiss = onDismiss, onConfirm = {
        when {
            title.isBlank() -> toast(context, "请填写标题")
            !isValidDate(due) -> toast(context, "日期格式应为 2026-01-31")
            else -> onSave(title, category, due.trim(), note)
        }
    }) {
        OutlinedTextField(value = title, onValueChange = { title = it }, label = { Text("标题，如：打猫三联") }, modifier = Modifier.fillMaxWidth(), singleLine = true)
        Spacer(Modifier.height(10.dp))
        SelectField("类别", REMINDER_CATEGORIES.map { it.key to it.value }, category) { category = it }
        Spacer(Modifier.height(10.dp))
        OutlinedTextField(value = due, onValueChange = { due = it }, label = { Text("日期（YYYY-MM-DD）") }, modifier = Modifier.fillMaxWidth(), singleLine = true)
        Spacer(Modifier.height(10.dp))
        OutlinedTextField(value = note, onValueChange = { note = it }, label = { Text("备注（可不填）") }, modifier = Modifier.fillMaxWidth())
    }
}

/* ---------- 体重 ---------- */

@Composable
fun WeightFormDialog(onDismiss: () -> Unit, onSave: (date: String, kg: Double) -> Unit) {
    val context = LocalContext.current
    var date by remember { mutableStateOf(todayKey()) }
    var kg by remember { mutableStateOf("") }

    FormDialog("记录体重", onDismiss = onDismiss, onConfirm = {
        val v = kg.toDoubleOrNull()
        when {
            !isValidDate(date) -> toast(context, "日期格式应为 2026-01-31")
            v == null || v <= 0 -> toast(context, "请填写体重")
            else -> onSave(date.trim(), v)
        }
    }) {
        OutlinedTextField(value = date, onValueChange = { date = it }, label = { Text("日期（YYYY-MM-DD）") }, modifier = Modifier.fillMaxWidth(), singleLine = true)
        Spacer(Modifier.height(10.dp))
        OutlinedTextField(
            value = kg, onValueChange = { kg = it.filter { c -> c.isDigit() || c == '.' } },
            label = { Text("体重（kg）") }, modifier = Modifier.fillMaxWidth(), singleLine = true,
            keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Decimal),
        )
    }
}

/* ---------- 宠物档案 ---------- */

@Composable
fun ProfileFormDialog(pet: Pet, onDismiss: () -> Unit, onSave: (name: String, species: String, breed: String, birthday: String, weight: String) -> Unit) {
    val context = LocalContext.current
    var name by remember { mutableStateOf(pet.name) }
    var species by remember { mutableStateOf(pet.species) }
    var breed by remember { mutableStateOf(pet.breed) }
    var birthday by remember { mutableStateOf(pet.birthday) }
    var weight by remember { mutableStateOf(pet.weight) }

    FormDialog("宠物档案", onDismiss = onDismiss, onConfirm = {
        when {
            name.isBlank() -> toast(context, "请填写名字")
            birthday.isNotBlank() && !isValidDate(birthday) -> toast(context, "生日格式应为 2024-05-20")
            else -> onSave(name, species, breed, birthday.trim(), weight)
        }
    }) {
        OutlinedTextField(value = name, onValueChange = { name = it }, label = { Text("名字") }, modifier = Modifier.fillMaxWidth(), singleLine = true)
        Spacer(Modifier.height(10.dp))
        ChipRow(SPECIES.map { it.key to it.value }, species) { species = it }
        Spacer(Modifier.height(10.dp))
        OutlinedTextField(value = breed, onValueChange = { breed = it }, label = { Text("品种，如：布偶猫") }, modifier = Modifier.fillMaxWidth(), singleLine = true)
        Spacer(Modifier.height(10.dp))
        OutlinedTextField(value = birthday, onValueChange = { birthday = it }, label = { Text("生日（YYYY-MM-DD，可不填）") }, modifier = Modifier.fillMaxWidth(), singleLine = true)
        Spacer(Modifier.height(10.dp))
        OutlinedTextField(
            value = weight, onValueChange = { weight = it.filter { c -> c.isDigit() || c == '.' } },
            label = { Text("当前体重（kg）") }, modifier = Modifier.fillMaxWidth(), singleLine = true,
            keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Decimal),
        )
    }
}

/* ---------- 成员 ---------- */

@Composable
fun MemberFormDialog(existing: List<Member>, onDismiss: () -> Unit, onSave: (name: String, role: String) -> Unit) {
    val context = LocalContext.current
    var name by remember { mutableStateOf("") }
    var role by remember { mutableStateOf("caregiver") }

    FormDialog("添加成员", onDismiss = onDismiss, confirmText = "添加", onConfirm = {
        when {
            name.isBlank() -> toast(context, "请填写名字")
            existing.any { it.name == name.trim() } -> toast(context, "已有同名成员")
            else -> onSave(name, role)
        }
    }) {
        OutlinedTextField(value = name, onValueChange = { name = it }, label = { Text("名字，如：妈妈") }, modifier = Modifier.fillMaxWidth(), singleLine = true)
        Spacer(Modifier.height(10.dp))
        ChipRow(listOf("caregiver" to "一起照顾", "viewer" to "只看看"), role) { role = it }
        Spacer(Modifier.height(8.dp))
        Text("成员只保存在本机，用来区分谁记了什么。", fontSize = 12.sp, color = CoveyMuted)
    }
}

/* ---------- 记录详情 ---------- */

@Composable
fun EntryDetailDialog(entry: Entry, state: CoveyState, onDismiss: () -> Unit, onDelete: () -> Unit) {
    var confirming by remember { mutableStateOf(false) }
    Dialog(onDismissRequest = onDismiss) {
        Surface(shape = RoundedCornerShape(20.dp), color = CoveyCard, modifier = Modifier.fillMaxWidth()) {
            Column(modifier = Modifier.padding(20.dp).verticalScroll(rememberScrollState())) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    EntryTypeTag(entry.type)
                    if (entry.amount != null) {
                        Spacer(Modifier.width(8.dp))
                        Text("¥%.2f".format(entry.amount), color = CoveyAccent, fontWeight = FontWeight.Bold)
                    }
                    Spacer(Modifier.weight(1f))
                    Text(fmtFullDateTime(entry.ts), fontSize = 11.sp, color = CoveyMuted)
                }
                Spacer(Modifier.height(12.dp))
                entry.photo?.let { b64 ->
                    base64ToBitmap(b64)?.let { bmp ->
                        Image(
                            bitmap = bmp.asImageBitmap(), contentDescription = "照片",
                            modifier = Modifier.fillMaxWidth().clip(RoundedCornerShape(14.dp)),
                            contentScale = ContentScale.FillWidth,
                        )
                        Spacer(Modifier.height(12.dp))
                    }
                }
                Text(entry.text.ifBlank { "（无文字）" }, fontSize = 15.sp, color = CoveyInk)
                Spacer(Modifier.height(10.dp))
                Text("记录人：${memberName(state, entry.by)}", fontSize = 12.sp, color = CoveyMuted)
                Spacer(Modifier.height(16.dp))
                Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.End) {
                    TextButton(onClick = { confirming = true }) { Text("删除", color = CoveyDanger) }
                    TextButton(onClick = onDismiss) { Text("关闭") }
                }
            }
        }
    }
    if (confirming) {
        ConfirmDialog("删除这条记录？", confirmText = "删除", onDismiss = { confirming = false }, onConfirm = {
            confirming = false
            onDelete()
        })
    }
}
