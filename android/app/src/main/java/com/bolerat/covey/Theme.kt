package com.bolerat.covey

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color

val CoveyInk = Color(0xFF3A3230)
val CoveyAccent = Color(0xFFD96F4E)
val CoveyAccentSoft = Color(0xFFF6E3DC)
val CoveySage = Color(0xFF6F8F5F)
val CoveySageSoft = Color(0xFFE4EDE1)
val CoveyBlue = Color(0xFF5B7FA6)
val CoveyBlueSoft = Color(0xFFE2EAF2)
val CoveyCream = Color(0xFFFAF6F1)
val CoveyCard = Color(0xFFFFFFFF)
val CoveyLine = Color(0xFFEDE4DA)
val CoveyMuted = Color(0xFF8A7F78)
val CoveyDanger = Color(0xFFC0533F)

@Composable
fun CoveyTheme(content: @Composable () -> Unit) {
    val scheme = lightColorScheme(
        primary = CoveyAccent,
        onPrimary = Color.White,
        primaryContainer = CoveyAccentSoft,
        onPrimaryContainer = CoveyInk,
        secondary = CoveySage,
        onSecondary = Color.White,
        secondaryContainer = CoveySageSoft,
        onSecondaryContainer = CoveyInk,
        tertiary = CoveyBlue,
        background = CoveyCream,
        onBackground = CoveyInk,
        surface = CoveyCard,
        onSurface = CoveyInk,
        surfaceVariant = Color(0xFFF1EAE2),
        onSurfaceVariant = CoveyMuted,
        outline = CoveyLine,
        error = CoveyDanger,
    )
    MaterialTheme(colorScheme = scheme, content = content)
}
