package com.bolerat.covey

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.util.Base64
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
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
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import kotlin.math.min

/* ---------- 卡片与小组件 ---------- */

@Composable
fun CoveyCard(modifier: Modifier = Modifier, content: @Composable () -> Unit) {
    Surface(
        modifier = modifier
            .fillMaxWidth()
            .border(1.dp, CoveyLine, RoundedCornerShape(18.dp)),
        shape = RoundedCornerShape(18.dp),
        color = CoveyCard,
    ) {
        Box(modifier = Modifier.padding(16.dp)) { content() }
    }
}

@Composable
fun SectionHeader(title: String, trailing: (@Composable () -> Unit)? = null) {
    Row(
        modifier = Modifier.fillMaxWidth().padding(horizontal = 4.dp, vertical = 6.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(title, style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold, color = CoveyInk)
        Spacer(Modifier.weight(1f))
        trailing?.invoke()
    }
}

@Composable
fun EntryTypeTag(type: String) {
    val (label, bg, fg) = when (type) {
        "care" -> Triple("照护", CoveySageSoft, CoveySage)
        "photo" -> Triple("照片", CoveyBlueSoft, CoveyBlue)
        "spend" -> Triple("花费", CoveyAccentSoft, CoveyAccent)
        "health" -> Triple("健康", Color(0xFFF3E3D8), Color(0xFFB0643C))
        else -> Triple("日常", Color(0xFFF1EAE2), CoveyMuted)
    }
    Surface(shape = RoundedCornerShape(8.dp), color = bg) {
        Text(label, modifier = Modifier.padding(horizontal = 8.dp, vertical = 3.dp), fontSize = 11.sp, color = fg, fontWeight = FontWeight.Medium)
    }
}

@Composable
fun EmptyState(text: String) {
    Column(
        modifier = Modifier.fillMaxWidth().padding(28.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Text("🐾", fontSize = 34.sp)
        Spacer(Modifier.height(8.dp))
        Text(text, color = CoveyMuted, fontSize = 13.sp)
    }
}

/* ---------- 宠物头像（带进度环） ---------- */

@Composable
fun PetAvatar(
    species: String,
    modifier: Modifier = Modifier,
    diameter: Dp = 84.dp,
    progress: Float? = null, // 0..1，显示进度环
) {
    val emoji = SPECIES_EMOJI[species] ?: "🐾"
    Box(modifier = modifier.size(diameter), contentAlignment = Alignment.Center) {
        if (progress != null) {
            Canvas(modifier = Modifier.fillMaxSize()) {
                val stroke = 6.dp.toPx()
                val d = this.size.minDimension
                val radius = (d - stroke) / 2f
                val arcSize = Size(radius * 2, radius * 2)
                val topLeft = Offset((d - radius * 2) / 2f, (d - radius * 2) / 2f)
                drawArc(Color(0xFFEDE4DA), 0f, 360f, false, topLeft, arcSize, style = Stroke(stroke))
                drawArc(
                    CoveyAccent, -90f, 360f * progress.coerceIn(0f, 1f), false,
                    topLeft, arcSize, style = Stroke(stroke, cap = StrokeCap.Round),
                )
            }
        }
        Box(
            modifier = Modifier
                .size(if (progress != null) diameter - 14.dp else diameter)
                .clip(CircleShape)
                .background(CoveyAccentSoft),
            contentAlignment = Alignment.Center,
        ) {
            Text(emoji, fontSize = (diameter.value * 0.42).sp)
        }
    }
}

/* ---------- 记录行 ---------- */

fun entryTypeEmoji(type: String): String = when (type) {
    "care" -> "✅"
    "photo" -> "📷"
    "spend" -> "💰"
    "health" -> "❤️"
    else -> "📝"
}

fun entryTypeBg(type: String): Color = when (type) {
    "care" -> CoveySageSoft
    "photo" -> CoveyBlueSoft
    "spend" -> CoveyAccentSoft
    "health" -> Color(0xFFF3E3D8)
    else -> Color(0xFFF1EAE2)
}

@Composable
fun EntryRow(entry: Entry, onClick: (() -> Unit)?, state: CoveyState) {
    val photoThumb = entry.photo?.let { base64ToBitmap(it) }
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(14.dp))
            .then(if (onClick != null) Modifier.clickable(onClick = onClick) else Modifier)
            .padding(vertical = 8.dp, horizontal = 4.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Box(
            modifier = Modifier
                .size(40.dp)
                .clip(RoundedCornerShape(12.dp))
                .background(entryTypeBg(entry.type)),
            contentAlignment = Alignment.Center,
        ) {
            Text(entryTypeEmoji(entry.type), fontSize = 18.sp)
        }
        Spacer(Modifier.width(12.dp))
        Column(modifier = Modifier.weight(1f)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                EntryTypeTag(entry.type)
                if (entry.amount != null) {
                    Spacer(Modifier.width(6.dp))
                    Text("¥%.0f".format(entry.amount), fontSize = 12.sp, color = CoveyAccent, fontWeight = FontWeight.Bold)
                }
            }
            Spacer(Modifier.height(2.dp))
            Text(
                entry.text.ifBlank { "（无文字）" },
                maxLines = 2, overflow = TextOverflow.Ellipsis,
                fontSize = 14.sp, color = CoveyInk,
            )
            Spacer(Modifier.height(2.dp))
            Text(
                "${timeKeyOf(entry.ts)} · ${memberName(state, entry.by)}",
                fontSize = 11.sp, color = CoveyMuted,
            )
        }
        if (photoThumb != null) {
            Spacer(Modifier.width(10.dp))
            androidx.compose.foundation.Image(
                bitmap = photoThumb.asImageBitmap(),
                contentDescription = "照片",
                modifier = Modifier.size(44.dp).clip(RoundedCornerShape(10.dp)),
                contentScale = ContentScale.Crop,
            )
        }
    }
}

/* ---------- 图片工具 ---------- */

fun bitmapToBase64(bmp: Bitmap): String {
    val maxSide = 1024
    val scale = min(1f, maxSide.toFloat() / maxOf(bmp.width, bmp.height))
    val scaled = if (scale < 1f) {
        Bitmap.createScaledBitmap(
            bmp,
            (bmp.width * scale).toInt().coerceAtLeast(1),
            (bmp.height * scale).toInt().coerceAtLeast(1),
            true,
        )
    } else bmp
    val out = java.io.ByteArrayOutputStream()
    scaled.compress(Bitmap.CompressFormat.JPEG, 70, out)
    return Base64.encodeToString(out.toByteArray(), Base64.NO_WRAP)
}

fun base64ToBitmap(b64: String): Bitmap? = try {
    val bytes = Base64.decode(b64, Base64.DEFAULT)
    BitmapFactory.decodeByteArray(bytes, 0, bytes.size)
} catch (e: Exception) { null }
