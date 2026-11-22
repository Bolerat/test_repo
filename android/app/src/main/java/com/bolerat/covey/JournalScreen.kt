package com.bolerat.covey

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

@Composable
fun JournalScreen() {
    val state = Store.state
    var query by remember { mutableStateOf("") }
    var filter by remember { mutableStateOf("all") }
    var detailEntry by remember { mutableStateOf<Entry?>(null) }

    val filtered = state.entries.filter { e ->
        val typeOk = filter == "all" || e.type == filter
        val q = query.trim()
        val queryOk = q.isEmpty() || e.text.contains(q, ignoreCase = true)
        typeOk && queryOk
    }
    val groups = filtered.groupBy { dateKeyOf(it.ts) }

    Column(modifier = Modifier.fillMaxSize().padding(horizontal = 16.dp)) {
        Spacer(Modifier.height(12.dp))
        Text("记录", style = MaterialTheme.typography.headlineSmall, fontWeight = FontWeight.Bold, color = CoveyInk)
        Text("照片、花费、健康和日常，都按时间存好。", fontSize = 13.sp, color = CoveyMuted)
        Spacer(Modifier.height(10.dp))

        OutlinedTextField(
            value = query, onValueChange = { query = it },
            placeholder = { Text("搜索记录…") }, modifier = Modifier.fillMaxWidth(), singleLine = true,
            shape = RoundedCornerShape(14.dp),
        )
        Spacer(Modifier.height(8.dp))

        Row(modifier = Modifier.fillMaxWidth().height(40.dp)) {
            androidx.compose.foundation.lazy.LazyRow {
                items(JOURNAL_FILTERS) { (key, label) ->
                    val selected = filter == key
                    Surface(
                        onClick = { filter = key },
                        shape = RoundedCornerShape(999.dp),
                        color = if (selected) CoveyAccent else ChipIdle,
                        modifier = Modifier.padding(end = 8.dp),
                    ) {
                        Text(
                            label,
                            modifier = Modifier.padding(horizontal = 14.dp, vertical = 8.dp),
                            fontSize = 13.sp,
                            color = if (selected) androidx.compose.ui.graphics.Color.White else CoveyMuted,
                            fontWeight = if (selected) FontWeight.Bold else FontWeight.Normal,
                        )
                    }
                }
            }
        }
        Spacer(Modifier.height(6.dp))

        if (groups.isEmpty()) {
            Spacer(Modifier.height(40.dp))
            CoveyCard { EmptyState(if (query.isNotBlank()) "没有找到相关记录" else "还没有记录，去「今日」记一笔吧") }
        } else {
            LazyColumn(modifier = Modifier.fillMaxSize()) {
                groups.forEach { (day, entries) ->
                    item(key = "h-$day") {
                        Text(
                            "${fmtDateCN(day)} · ${entries.size} 条",
                            modifier = Modifier.padding(top = 14.dp, bottom = 4.dp, start = 4.dp),
                            fontSize = 13.sp, fontWeight = FontWeight.Bold, color = CoveyMuted,
                        )
                    }
                    items(entries, key = { it.id }) { e ->
                        EntryRow(e, onClick = { detailEntry = e }, state = state)
                    }
                }
                item { Spacer(Modifier.height(24.dp)) }
            }
        }
    }

    detailEntry?.let { e ->
        EntryDetailDialog(entry = e, state = state, onDismiss = { detailEntry = null }) {
            Store.deleteEntry(e.id)
            detailEntry = null
        }
    }
}
