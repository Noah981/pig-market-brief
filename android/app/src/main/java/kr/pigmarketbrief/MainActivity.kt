package kr.pigmarketbrief

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent { MaterialTheme { BriefingApp() } }
    }
}

@Composable
fun BriefingApp() {
    var tab by remember { mutableIntStateOf(0) }
    Scaffold(
        bottomBar = {
            NavigationBar {
                listOf("홈","시황","농장점검","지역").forEachIndexed { i, t ->
                    NavigationBarItem(selected=tab==i,onClick={tab=i},icon={},label={Text(t)})
                }
            }
        }
    ) { pad ->
        Column(Modifier.padding(pad).padding(16.dp).verticalScroll(rememberScrollState()), verticalArrangement=Arrangement.spacedBy(12.dp)) {
            Text("양돈 브리핑", style=MaterialTheme.typography.headlineMedium)
            when(tab) {
                0 -> Home()
                1 -> Market()
                2 -> Checklist()
                else -> Region()
            }
        }
    }
}
@Composable fun Home() {
    Text("대한민국 전역 · 제주 포함", style=MaterialTheme.typography.titleMedium)
    Card { Column(Modifier.padding(16.dp)) { Text("오늘 돼지 경락가격"); Text("공식 데이터 연결 준비 중") } }
    Card { Column(Modifier.padding(16.dp)) { Text("제주 흑돼지"); Text("제주 공식 데이터 범위로 별도 표시") } }
    Card { Column(Modifier.padding(16.dp)) { Text("오늘 날씨 · 특보 · 일교차"); Text("관심지역 설정 후 자동 반영") } }
    Card { Column(Modifier.padding(16.dp)) { Text("오늘의 농장 체크"); Text("날씨·질병·가격·계절을 반영해 우선순위 자동 생성") } }
}
@Composable fun Market() { Text("7일/30일 가격추이 · 월평균 · 전년동월 · 경락/도축 지표"); Text("사실과 관련 체크요인을 분리해 표시합니다.") }
@Composable fun Checklist() {
    Text("농장 점검", style=MaterialTheme.typography.titleLarge)
    listOf("급이·사료","음수","환기·환경","질병·위생","모돈·자돈","출하·기록").forEach {
        Card { Row(Modifier.fillMaxWidth().padding(16.dp), horizontalArrangement=Arrangement.SpaceBetween) { Text(it); Text("양호 · 주의 · 불량") } }
    }
    Text("점검 결과를 바탕으로 우선 개선사항 TOP 3를 생성합니다.")
}
@Composable fun Region() { Text("관심지역"); Text("17개 시·도 → 시·군·구 선택 · 제주 포함") }
