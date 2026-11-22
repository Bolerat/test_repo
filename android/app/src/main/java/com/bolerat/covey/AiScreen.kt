package com.bolerat.covey

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
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
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import kotlinx.coroutines.launch

@Composable
fun AiScreen(pendingPrompt: String?, onConsumePrompt: () -> Unit) {
    val state = Store.state
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    var input by remember { mutableStateOf("") }
    var busy by remember { mutableStateOf(false) }
    val listState = rememberLazyListState()
    val chat = state.chat

    LaunchedEffect(chat.size) {
        if (chat.isNotEmpty()) listState.animateScrollToItem(chat.size - 1)
    }

    fun send(text: String) {
        val content = text.trim()
        if (content.isEmpty() || busy) return
        if (!state.ai.configured) {
            toast(context, "请先在「设置」里配置 AI")
            return
        }
        Store.appendChat("user", content)
        busy = true
        scope.launch {
            try {
                val history = Store.state.chat.takeLast(20).map { ChatTurn(it.role, it.content) }
                val turns = listOf(ChatTurn("system", buildSystemPrompt(Store.state))) + history
                val reply = chatWithAi(Store.state.ai, turns)
                Store.appendChat("assistant", reply)
            } catch (e: Exception) {
                Store.appendChat("assistant", "（出了点问题：${e.message ?: e}）稍后再试试？")
            } finally {
                busy = false
            }
        }
    }

    LaunchedEffect(pendingPrompt) {
        pendingPrompt?.let {
            send(it)
            onConsumePrompt()
        }
    }

    Column(modifier = Modifier.fillMaxSize().imePadding()) {
        Column(modifier = Modifier.padding(horizontal = 16.dp)) {
            Spacer(Modifier.height(12.dp))
            Text("AI 助手 Pawly", style = MaterialTheme.typography.headlineSmall, fontWeight = FontWeight.Bold, color = CoveyInk)
            Text("记得越多，建议越靠谱。", fontSize = 13.sp, color = CoveyMuted)
            Spacer(Modifier.height(8.dp))
        }

        if (chat.isEmpty()) {
            Column(
                modifier = Modifier.weight(1f).fillMaxWidth().padding(horizontal = 24.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.Center,
            ) {
                Text("🐾", fontSize = 44.sp)
                Spacer(Modifier.height(10.dp))
                Text("我是 Pawly，会记得${state.pet.name}最近的日常。", color = CoveyInk, fontSize = 15.sp)
                Spacer(Modifier.height(6.dp))
                Text("可以问我：今天要注意什么、最近状态怎么样、要不要记录体重。", color = CoveyMuted, fontSize = 13.sp)
                Spacer(Modifier.height(16.dp))
                listOf(
                    "给我 3 条今天可以做的事",
                    "${state.pet.name}最近状态怎么样",
                    "体重需要注意吗",
                ).forEach { q ->
                    Surface(
                        onClick = { send(q) },
                        shape = RoundedCornerShape(999.dp),
                        color = CoveyCard, border = androidx.compose.foundation.BorderStroke(1.dp, CoveyLine),
                        modifier = Modifier.padding(vertical = 4.dp),
                    ) {
                        Text(q, modifier = Modifier.padding(horizontal = 16.dp, vertical = 9.dp), fontSize = 13.sp, color = CoveyInk)
                    }
                }
            }
        } else {
            LazyColumn(
                state = listState,
                modifier = Modifier.weight(1f).fillMaxWidth(),
                contentPadding = PaddingValues(horizontal = 16.dp, vertical = 8.dp),
            ) {
                items(chat) { msg -> ChatBubble(msg) }
                if (busy) {
                    item {
                        Row(modifier = Modifier.padding(vertical = 6.dp)) {
                            Surface(shape = RoundedCornerShape(16.dp), color = CoveyCard, border = androidx.compose.foundation.BorderStroke(1.dp, CoveyLine)) {
                                Row(modifier = Modifier.padding(horizontal = 14.dp, vertical = 10.dp), verticalAlignment = Alignment.CenterVertically) {
                                    CircularProgressIndicator(modifier = Modifier.size(14.dp), strokeWidth = 2.dp, color = CoveyAccent)
                                    Spacer(Modifier.width(8.dp))
                                    Text("Pawly 正在输入…", fontSize = 13.sp, color = CoveyMuted)
                                }
                            }
                        }
                    }
                }
            }
        }

        // 输入栏
        Row(
            modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 10.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            OutlinedTextField(
                value = input, onValueChange = { input = it },
                placeholder = { Text("问点什么…") },
                modifier = Modifier.weight(1f), singleLine = false,
                maxLines = 4, shape = RoundedCornerShape(22.dp),
            )
            Spacer(Modifier.width(8.dp))
            Button(
                onClick = { send(input); input = "" },
                enabled = input.isNotBlank() && !busy,
                shape = RoundedCornerShape(22.dp),
                colors = ButtonDefaults.buttonColors(containerColor = CoveyAccent),
            ) { Text("发送") }
        }
        if (!state.ai.configured) {
            Text(
                "还没有配置 AI，去「设置」填一下 API 就能用。",
                modifier = Modifier.padding(horizontal = 20.dp),
                fontSize = 12.sp, color = CoveyMuted,
            )
            Spacer(Modifier.height(8.dp))
        }
    }
}

@Composable
private fun ChatBubble(msg: ChatMessage) {
    val isUser = msg.role == "user"
    Row(
        modifier = Modifier.fillMaxWidth().padding(vertical = 4.dp),
        horizontalArrangement = if (isUser) Arrangement.End else Arrangement.Start,
    ) {
        Surface(
            shape = RoundedCornerShape(16.dp),
            color = if (isUser) CoveyAccentSoft else CoveyCard,
            border = if (isUser) null else androidx.compose.foundation.BorderStroke(1.dp, CoveyLine),
            modifier = Modifier.widthIn(max = 300.dp),
        ) {
            Column(modifier = Modifier.padding(horizontal = 14.dp, vertical = 10.dp)) {
                if (!isUser) Text("Pawly", fontSize = 11.sp, color = CoveyAccent, fontWeight = FontWeight.Bold)
                Text(msg.content, fontSize = 14.sp, color = CoveyInk)
            }
        }
    }
}
