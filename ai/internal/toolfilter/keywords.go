package toolfilter

import (
	"sort"
	"strings"
	"unicode"
	"unicode/utf8"
)

// categoryKeywords maps each built-in tool category to utterance words that
// clearly signal it, Japanese and English mixed. Deliberately conservative:
// a hit only ever adds a category, and anything ambiguous is left to the
// embedding layer, so precision matters more than recall here. MCP server
// categories have no entries — their vocabulary is unknown at compile time —
// and are covered by embeddings alone.
var categoryKeywords = map[string][]string{
	"audio": {
		"音量", "ボリューム", "ミュート", "消音", "うるさい", "静かに", "マイク",
		"volume", "mute", "unmute", "louder", "quieter", "mic", "microphone", "sound",
	},
	"music": {
		"曲", "音楽", "再生", "一時停止", "次の曲", "前の曲", "スキップ", "止めて",
		"music", "song", "track", "play", "pause", "skip", "playback",
	},
	"panel": {
		"パネル", "設定画面", "設定開", "ランチャー",
		"panel", "settings", "launcher",
	},
	"brightness": {
		"明るさ", "輝度", "まぶし", "眩し", "暗くして", "明るくして", "画面を暗く", "画面を明るく",
		"brightness", "brighter", "darker", "dim",
	},
	"theme": {
		"テーマ", "ダーク", "ライトモード", "夜モード",
		"theme", "dark", "light mode",
	},
	"wallpaper": {
		"壁紙",
		"wallpaper", "background",
	},
	"notification": {
		"通知", "サイレント", "おやすみモード", "集中モード",
		"notification", "notifications", "dnd", "disturb", "unread",
	},
	"app": {
		"起動して", "開いて", "立ち上げて", "アプリ", "ブラウザ", "ターミナル",
		"launch", "open", "start", "run", "app", "browser", "terminal",
	},
	"timer": {
		"タイマー", "分後", "秒後", "分測って", "カウントダウン", "アラーム",
		"timer", "countdown", "alarm", "minutes", "remind me in",
	},
	"calendar": {
		"予定", "カレンダー", "スケジュール", "イベント", "リマインド",
		"calendar", "event", "schedule", "appointment", "meeting",
	},
	"memory": {
		"覚えて", "覚えといて", "記憶", "忘れて", "忘れないで",
		"remember", "forget", "memorize", "memory",
	},
	"weather": {
		"天気", "気温", "雨", "雪", "晴れ", "暑い", "寒い", "傘",
		"weather", "temperature", "rain", "snow", "sunny", "forecast", "umbrella",
	},
}

// keywordHits returns the categories whose keywords appear in the utterance,
// restricted to categories actually present in the registry. ASCII keywords
// match on word boundaries so "mic" can't fire inside "dynamic"; Japanese
// keywords match as plain substrings (no word boundaries to lean on).
func keywordHits(utterance string, cats map[string]bool) []string {
	low := strings.ToLower(utterance)
	var out []string
	for cat, kws := range categoryKeywords {
		if !cats[cat] {
			continue
		}
		for _, kw := range kws {
			if matchKeyword(low, kw) {
				out = append(out, cat)
				break
			}
		}
	}
	sort.Strings(out)
	return out
}

func matchKeyword(lowUtterance, kw string) bool {
	if isASCII(kw) {
		return containsWord(lowUtterance, strings.ToLower(kw))
	}
	return strings.Contains(lowUtterance, kw)
}

func isASCII(s string) bool {
	for _, r := range s {
		if r > unicode.MaxASCII {
			return false
		}
	}
	return true
}

// containsWord reports whether the ASCII keyword w occurs in s not glued to
// another ASCII alphanumeric (so "mic" doesn't match inside "dynamic"). A
// non-ASCII neighbour — any CJK character — counts as a boundary, since it
// can't be part of the same English token; neighbours are decoded as full
// runes rather than single bytes so a multibyte char's trailing byte isn't
// mistaken for a boundary of its own.
func containsWord(s, w string) bool {
	for from := 0; ; {
		i := strings.Index(s[from:], w)
		if i < 0 {
			return false
		}
		i += from
		before := true
		if i > 0 {
			r, _ := utf8.DecodeLastRuneInString(s[:i])
			before = !isASCIIWord(r)
		}
		afterIdx := i + len(w)
		after := true
		if afterIdx < len(s) {
			r, _ := utf8.DecodeRuneInString(s[afterIdx:])
			after = !isASCIIWord(r)
		}
		if before && after {
			return true
		}
		from = i + 1
	}
}

// isASCIIWord reports whether r continues an ASCII word token. Only ASCII
// letters/digits qualify: an adjacent CJK rune ends the English token.
func isASCIIWord(r rune) bool {
	return (r >= 'a' && r <= 'z') || (r >= 'A' && r <= 'Z') || (r >= '0' && r <= '9')
}

// categoryHasKeywords reports whether a category can be assessed by the
// keyword layer at all. Categories with no dictionary entry — every MCP
// server, whose vocabulary is unknown at compile time — can only be scored
// by embeddings, so in keyword-only mode they must never be trimmed away.
func categoryHasKeywords(cat string) bool {
	_, ok := categoryKeywords[cat]
	return ok
}
