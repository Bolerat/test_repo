package com.bolerat.covey

import android.net.Uri
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Surface
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

@Composable
fun MeScreen(onNavigatePet: () -> Unit) {
    val state = Store.state
    val context = LocalContext.current
    val scope = rememberCoroutineScope()

    // AI 表单（以已保存配置为初值；保存后随 state.ai 重置）
    var provider by remember(state.ai) { mutableStateOf(state.ai.provider) }
    var baseUrl by remember(state.ai) { mutableStateOf(state.ai.baseUrl) }
    var apiKey by remember(state.ai) { mutableStateOf(state.ai.apiKey) }
    var model by remember(state.ai) { mutableStateOf(state.ai.model) }
    var tone by remember(state.ai) { mutableStateOf(state.ai.tone) }
    var testResult by remember { mutableStateOf("") }
    var testing by remember { mutableStateOf(false) }

    var showClearConfirm by remember { mutableStateOf(false) }

    fun currentAi() = AIConfig(provider, baseUrl, apiKey, model, tone)

    val exportLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.CreateDocument("application/json"),
    ) { uri: Uri? ->
        uri?.let {
            scope.launch {
                val ok = withContext(Dispatchers.IO) {
                    try {
                        context.contentResolver.openOutputStream(it)?.use { out ->
                            out.write(Store.state.toJson().toByteArray(Charsets.UTF_8))
                        }
                        true
                    } catch (e: Exception) { false }
                }
                toast(context, if (ok) "已导出" else "导出失败")
            }
        }
    }

    val importLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.OpenDocument(),
    ) { uri: Uri? ->
        uri?.let {
            scope.launch {
                val result = withContext(Dispatchers.IO) {
                    try {
                        val text = context.contentResolver.openInputStream(it)?.use { s ->
                            s.bufferedReader(Charsets.UTF_8).readText()
                        } ?: return@withContext null
                        coveyStateFromJson(text)
                    } catch (e: Exception) { null }
                }
                if (result != null) {
                    Store.replaceAll(result)
                    toast(context, "导入成功")
                } else {
                    toast(context, "文件格式不正确")
                }
            }
        }
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(horizontal = 16.dp),
    ) {
        Spacer(Modifier.height(12.dp))
        Text("设置", style = MaterialTheme.typography.headlineSmall, fontWeight = FontWeight.Bold, color = CoveyInk)
        Text("AI 助手、提醒、数据与本地存储。", fontSize = 13.sp, color = CoveyMuted)
        Spacer(Modifier.height(12.dp))

        // AI 助手
        CoveyCard {
            Text("AI 助手", style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold, color = CoveyInk)
            Spacer(Modifier.height(12.dp))
            SelectField("服务商", AI_PROVIDERS.map { it.key to it.label }, provider) { key ->
                provider = key
                val preset = AI_PROVIDERS.firstOrNull { it.key == key }
                if (preset != null && key != "custom") {
                    baseUrl = preset.baseUrl
                    model = preset.model
                }
            }
            Spacer(Modifier.height(10.dp))
            OutlinedTextField(value = baseUrl, onValueChange = { baseUrl = it }, label = { Text("API 地址（OpenAI 兼容）") }, modifier = Modifier.fillMaxWidth(), singleLine = true)
            Spacer(Modifier.height(10.dp))
            OutlinedTextField(
                value = apiKey, onValueChange = { apiKey = it },
                label = { Text("API Key") }, modifier = Modifier.fillMaxWidth(), singleLine = true,
                visualTransformation = PasswordVisualTransformation(),
            )
            Spacer(Modifier.height(10.dp))
            OutlinedTextField(value = model, onValueChange = { model = it }, label = { Text("模型") }, modifier = Modifier.fillMaxWidth(), singleLine = true)
            Spacer(Modifier.height(10.dp))
            SelectField("AI 语气", AI_TONES.map { it.key to it.label }, tone) { tone = it }
            Spacer(Modifier.height(8.dp))
            Text("配置只保存在本机。若接口不支持浏览器跨域访问，请填入支持 CORS 的代理地址。", fontSize = 12.sp, color = CoveyMuted)
            Spacer(Modifier.height(12.dp))
            Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                OutlinedButton(
                    onClick = {
                        if (testing) return@OutlinedButton
                        testing = true
                        testResult = "测试中…"
                        scope.launch {
                            val res = withContext(Dispatchers.IO) { testAiConnection(currentAi()) }
                            testResult = res
                            testing = false
                            toast(context, if (res.startsWith("连接成功")) "连接成功" else "连接失败")
                        }
                    },
                    modifier = Modifier.weight(1f), shape = RoundedCornerShape(12.dp),
                ) { Text("测试连接") }
                Button(
                    onClick = {
                        Store.saveAIConfig(provider, baseUrl, apiKey, model, tone)
                        testResult = ""
                        toast(context, "AI 配置已保存")
                    },
                    modifier = Modifier.weight(1f), shape = RoundedCornerShape(12.dp),
                ) { Text("保存") }
            }
            if (testResult.isNotBlank()) {
                Spacer(Modifier.height(8.dp))
                Text(
                    testResult,
                    fontSize = 13.sp,
                    color = if (testResult.startsWith("连接成功")) CoveySage else CoveyDanger,
                )
            }
        }
        Spacer(Modifier.height(12.dp))

        // 提醒
        CoveyCard {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Column(modifier = Modifier.weight(1f)) {
                    Text("Pawly 提醒", style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold, color = CoveyInk)
                    Text("开启后「今日」页显示 7 天内到期的提醒", fontSize = 12.sp, color = CoveyMuted)
                }
                Switch(
                    checked = state.remindersEnabled,
                    onCheckedChange = { v -> Store.update { it.copy(remindersEnabled = v) } },
                )
            }
        }
        Spacer(Modifier.height(12.dp))

        // 宠物与亲友
        CoveyCard {
            Text("宠物与亲友", style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold, color = CoveyInk)
            Spacer(Modifier.height(8.dp))
            SettingRow("宠物档案", "${state.pet.name} · ${SPECIES[state.pet.species] ?: "其他"}") { onNavigatePet() }
            SettingRow("家庭成员", "${state.members.size} 位成员，本机保存") { onNavigatePet() }
        }
        Spacer(Modifier.height(12.dp))

        // Pawly 的记忆
        CoveyCard {
            Text("Pawly 的记忆", style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold, color = CoveyInk)
            Spacer(Modifier.height(6.dp))
            Text(
                "AI 回答时会读取：宠物档案、最近 15 条记录、近 14 天每天的记录数量、体重、待办提醒和最近对话。这些只在你配置了 API 后发送给对应的 AI 服务。",
                fontSize = 13.sp, color = CoveyMuted,
            )
        }
        Spacer(Modifier.height(12.dp))

        // 数据与隐私
        CoveyCard {
            Text("数据与隐私", style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold, color = CoveyInk)
            Spacer(Modifier.height(8.dp))
            SettingRow("导出数据", "下载全部记录为 JSON 文件") {
                exportLauncher.launch("covey-backup-${todayKey()}.json")
            }
            SettingRow("导入数据", "从 JSON 文件恢复（会覆盖当前数据）") {
                importLauncher.launch(arrayOf("application/json", "text/*", "*/*"))
            }
            SettingRow("清空数据", "删除本机全部记录，不可恢复", danger = true) { showClearConfirm = true }
        }
        Spacer(Modifier.height(12.dp))

        // 关于
        CoveyCard {
            Text("关于", style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold, color = CoveyInk)
            Spacer(Modifier.height(6.dp))
            Text("同窝 Covey · 让和宠物一起生活的日常，被好好记住。", fontSize = 13.sp, color = CoveyMuted)
            Spacer(Modifier.height(4.dp))
            Text("数据只保存在本机，不上传。", fontSize = 12.sp, color = CoveyMuted)
        }
        Spacer(Modifier.height(24.dp))
    }

    if (showClearConfirm) {
        ConfirmDialog("确定清空所有数据吗？此操作不可恢复。", confirmText = "清空", onDismiss = { showClearConfirm = false }, onConfirm = {
            showClearConfirm = false
            Store.reset()
            toast(context, "已清空")
        })
    }
}

@Composable
private fun SettingRow(title: String, subtitle: String, danger: Boolean = false, onClick: () -> Unit) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = 4.dp)
            .clip(RoundedCornerShape(10.dp))
            .clickable { onClick() }
            .padding(horizontal = 4.dp, vertical = 8.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Column(modifier = Modifier.weight(1f)) {
            Text(title, fontSize = 14.sp, color = if (danger) CoveyDanger else CoveyInk, fontWeight = FontWeight.Medium)
            Text(subtitle, fontSize = 12.sp, color = CoveyMuted)
        }
        Text("›", fontSize = 18.sp, color = CoveyMuted)
    }
}
