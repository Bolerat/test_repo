package com.bolerat.covey

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.Scaffold
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

enum class Tab(val label: String, val emoji: String) {
    Today("今日", "🏠"),
    Journal("记录", "📖"),
    Ai("AI 助手", "✨"),
    Pet("宠物", "🐾"),
    Me("设置", "👤"),
}

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        Store.init(this)
        enableEdgeToEdge()
        setContent {
            CoveyTheme {
                CoveyApp()
            }
        }
    }
}

@Composable
fun CoveyApp() {
    var tab by remember { mutableStateOf(Tab.Today) }
    var pendingAiPrompt by remember { mutableStateOf<String?>(null) }

    Scaffold(
        bottomBar = {
            NavigationBar(containerColor = CoveyCard) {
                Tab.entries.forEach { t ->
                    NavigationBarItem(
                        selected = tab == t,
                        onClick = { tab = t },
                        icon = { Text(t.emoji, fontSize = 20.sp) },
                        label = {
                            Text(
                                t.label, fontSize = 11.sp,
                                fontWeight = if (tab == t) FontWeight.Bold else FontWeight.Normal,
                            )
                        },
                        colors = androidx.compose.material3.NavigationBarItemDefaults.colors(
                            selectedIconColor = CoveyAccent,
                            selectedTextColor = CoveyAccent,
                            indicatorColor = CoveyAccentSoft,
                        ),
                    )
                }
            }
        },
        containerColor = CoveyCream,
    ) { padding ->
        Box(modifier = Modifier.fillMaxSize().padding(padding)) {
            when (tab) {
                Tab.Today -> TodayScreen(onAskAi = { q -> pendingAiPrompt = q; tab = Tab.Ai })
                Tab.Journal -> JournalScreen()
                Tab.Ai -> AiScreen(pendingPrompt = pendingAiPrompt, onConsumePrompt = { pendingAiPrompt = null })
                Tab.Pet -> PetScreen()
                Tab.Me -> MeScreen(onNavigatePet = { tab = Tab.Pet })
            }
        }
    }
}
