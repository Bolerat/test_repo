package com.bolerat.covey

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
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
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.MaterialTheme
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
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

@Composable
fun PetScreen() {
    val state = Store.state
    val context = LocalContext.current
    val pet = state.pet

    var showProfile by remember { mutableStateOf(false) }
    var showWeight by remember { mutableStateOf(false) }
    var showMember by remember { mutableStateOf(false) }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(horizontal = 16.dp),
    ) {
        Spacer(Modifier.height(12.dp))
        Text("宠物", style = MaterialTheme.typography.headlineSmall, fontWeight = FontWeight.Bold, color = CoveyInk)
        Text("档案、体重和家人。", fontSize = 13.sp, color = CoveyMuted)
        Spacer(Modifier.height(12.dp))

        // 档案
        CoveyCard {
            Row(verticalAlignment = Alignment.CenterVertically) {
                BoxAvatar(pet.species, pet.name)
                Spacer(Modifier.width(16.dp))
                Column(modifier = Modifier.weight(1f)) {
                    Text(pet.name, style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold, color = CoveyInk)
                    val age = ageText(pet.birthday)
                    Text(
                        listOf(SPECIES[pet.species] ?: "其他", pet.breed, age).filter { it.isNotBlank() }.joinToString(" · ").ifBlank { "还没填档案" },
                        fontSize = 13.sp, color = CoveyMuted,
                    )
                    pet.weight.takeIf { it.isNotBlank() }?.let {
                        Spacer(Modifier.height(4.dp))
                        Text("体重 ${it}kg", fontSize = 13.sp, color = CoveySage, fontWeight = FontWeight.Medium)
                    }
                }
            }
            Spacer(Modifier.height(12.dp))
            Button(
                onClick = { showProfile = true }, modifier = Modifier.fillMaxWidth(),
                shape = RoundedCornerShape(12.dp),
                colors = ButtonDefaults.buttonColors(containerColor = CoveyAccentSoft, contentColor = CoveyAccent),
            ) { Text("编辑档案") }
        }
        Spacer(Modifier.height(12.dp))

        // 体重
        CoveyCard {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text("体重记录", style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold, color = CoveyInk)
                Spacer(Modifier.weight(1f))
                TextButton(onClick = { showWeight = true }) { Text("+ 记录", color = CoveyAccent) }
            }
            val last = lastWeight(state)
            if (last == null) {
                Text("还没有体重记录，记一次可以留意变化趋势。", fontSize = 13.sp, color = CoveyMuted)
            } else {
                Text("最近：${last.kg}kg · ${last.date}", fontSize = 14.sp, color = CoveyInk)
                val recent = state.weights.takeLast(5).reversed()
                if (recent.size > 1) {
                    Spacer(Modifier.height(8.dp))
                    recent.forEach { w ->
                        Row(modifier = Modifier.fillMaxWidth().padding(vertical = 3.dp)) {
                            Text(w.date, fontSize = 13.sp, color = CoveyMuted, modifier = Modifier.weight(1f))
                            Text("${w.kg}kg", fontSize = 13.sp, color = CoveyInk, fontWeight = FontWeight.Medium)
                        }
                    }
                }
            }
        }
        Spacer(Modifier.height(12.dp))

        // 家庭成员
        CoveyCard {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text("家庭成员", style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold, color = CoveyInk)
                Spacer(Modifier.weight(1f))
                TextButton(onClick = { showMember = true }) { Text("+ 添加", color = CoveyAccent) }
            }
            state.members.forEach { m ->
                val active = m.id == state.activeMember
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(vertical = 4.dp)
                        .clip(RoundedCornerShape(10.dp))
                        .background(if (active) CoveyAccentSoft else androidx.compose.ui.graphics.Color.Transparent)
                        .padding(horizontal = 10.dp, vertical = 8.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Column(modifier = Modifier.weight(1f)) {
                        Text(m.name, fontSize = 14.sp, color = CoveyInk, fontWeight = if (active) FontWeight.Bold else FontWeight.Normal)
                        Text(if (m.role == "owner" || m.role == "caregiver") "照护人" else "围观", fontSize = 11.sp, color = CoveyMuted)
                    }
                    if (active) {
                        Surface(shape = RoundedCornerShape(8.dp), color = CoveyAccent) {
                            Text("当前", modifier = Modifier.padding(horizontal = 8.dp, vertical = 3.dp), fontSize = 11.sp, color = androidx.compose.ui.graphics.Color.White)
                        }
                    } else {
                        TextButton(onClick = { Store.switchMember(m.id) }) { Text("切换", color = CoveyAccent, fontSize = 12.sp) }
                    }
                }
            }
            Spacer(Modifier.height(4.dp))
            Text("成员只保存在本机。家人一起用的同步功能后续开放。", fontSize = 12.sp, color = CoveyMuted)
        }
        Spacer(Modifier.height(24.dp))
    }

    if (showProfile) {
        ProfileFormDialog(pet = pet, onDismiss = { showProfile = false }) { name, species, breed, birthday, weight ->
            Store.savePet(name, species, breed, birthday, weight)
            showProfile = false
            toast(context, "档案已保存")
        }
    }
    if (showWeight) {
        WeightFormDialog(onDismiss = { showWeight = false }) { date, kg ->
            Store.addWeight(date, kg)
            showWeight = false
            toast(context, "体重已记录")
        }
    }
    if (showMember) {
        MemberFormDialog(existing = state.members, onDismiss = { showMember = false }) { name, role ->
            Store.addMember(name, role)
            showMember = false
            toast(context, "已添加")
        }
    }
}

@Composable
private fun BoxAvatar(species: String, name: String) {
    val emoji = SPECIES_EMOJI[species] ?: "🐾"
    androidx.compose.foundation.layout.Box(
        modifier = Modifier
            .size(72.dp)
            .clip(CircleShape)
            .background(CoveyAccentSoft)
            .border(1.dp, CoveyLine, CircleShape),
        contentAlignment = Alignment.Center,
    ) {
        Text(emoji, fontSize = 36.sp)
    }
}
