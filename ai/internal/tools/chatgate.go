package tools

import (
	"regexp"
	"strings"
	"sync/atomic"
	"unicode"
	"unicode/utf8"
)

// ChatGate decides which tool calls of one chat turn wait for the user's approval.
type ChatGate struct {
	r               *Registry
	askedToRemember bool
	freeSaveSpent   atomic.Bool
}

// ChatGate starts the gate for one user turn. userText is what the user typed, never the
// desktop snapshot or anything else the model read.
func (r *Registry) ChatGate(userText string) *ChatGate {
	return &ChatGate{r: r, askedToRemember: mentionsMemoryIntent(userText)}
}

// Needs reports whether the call must be approved first. Ask once per call: the first memory_save
// the user asked for in a turn runs unasked and uses up the turn's free save.
func (g *ChatGate) Needs(name string) bool {
	// Call() refuses a disabled category, so a card would ask about something that cannot happen.
	if g.r.IsCategoryDisabled(CategoryOf(name)) {
		return false
	}
	if g.r.NeedsConfirm(name) {
		return true
	}
	if name != "memory_save" || g.r.Find(name) == nil {
		return false
	}
	// The user's words vouch for one save per turn, not for however many the model decides to make.
	return !(g.askedToRemember && g.freeSaveSpent.CompareAndSwap(false, true))
}

// Request forms only: the runes in notNext turn a stem into recall, negation, past or progressive.
var japaneseStems = []struct {
	stems   []string
	notNext string
}{
	{[]string{"覚えて", "おぼえて", "記憶して", "メモして"}, "るなたいまらん"},
	{[]string{"覚えと", "おぼえと", "記憶しと", "メモしと", "メモっと"}, "るっ"},
}

var japaneseRequests = []string{"忘れないで", "わすれないで", "忘れずに", "わすれずに"}

var englishRequests = regexp.MustCompile(`\b(?:don't\s+forget|dont\s+forget|do\s+not\s+forget|keep\s+in\s+mind|from\s+now\s+on|note\s+that|to\s+memory|to\s+your\s+memory|in\s+your\s+memory)\b`)

var rememberVerb = regexp.MustCompile(`\b(?:remember|memorize|memorise)\b`)

var questionOrNegation = map[string]bool{
	"do": true, "does": true, "did": true, "you": true, "don't": true, "dont": true,
	"not": true, "never": true, "can't": true, "cannot": true,
	"i": true, "he": true, "she": true, "we": true, "they": true, "it": true,
	"doesn't": true, "didn't": true, "couldn't": true, "won't": true, "wouldn't": true, "shouldn't": true,
	"doesnt": true, "didnt": true, "cant": true, "wont": true,
	"can": true, "could": true, "will": true, "would": true, "should": true, "might": true, "may": true,
}

func mentionsMemoryIntent(s string) bool {
	s = foldIntentText(s)
	for _, p := range japaneseRequests {
		if strings.Contains(s, p) {
			return true
		}
	}
	for _, g := range japaneseStems {
		for _, stem := range g.stems {
			if hasRequestStem(s, stem, g.notNext) {
				return true
			}
		}
	}
	return englishRequests.MatchString(s) || asksToRemember(s)
}

// Japanese IMEs emit fullwidth ASCII, and phones the typographic apostrophe.
func foldIntentText(s string) string {
	return strings.Map(func(r rune) rune {
		switch {
		case r == '’':
			r = '\''
		case r >= 0xFF01 && r <= 0xFF5E:
			r -= 0xFEE0
		}
		return unicode.ToLower(r)
	}, s)
}

func hasRequestStem(s, stem, notNext string) bool {
	for {
		i := strings.Index(s, stem)
		if i < 0 {
			return false
		}
		s = s[i+len(stem):]
		if next, _ := utf8.DecodeRuneInString(s); !strings.ContainsRune(notNext, next) {
			return true
		}
	}
}

func asksToRemember(s string) bool {
	for _, loc := range rememberVerb.FindAllStringIndex(s, -1) {
		// Only an adjacent word counts: punctuation in between ("you, remember") ends the question.
		if questionOrNegation[wordBefore(s[:loc[0]])] || wordAfter(s[loc[1]:]) == "when" {
			continue
		}
		return true
	}
	return false
}

func isWordRune(r rune) bool {
	return r == '\'' || r >= 'a' && r <= 'z' || r >= '0' && r <= '9'
}

func wordBefore(s string) string {
	s = strings.TrimRightFunc(s, unicode.IsSpace)
	i := strings.LastIndexFunc(s, func(r rune) bool { return !isWordRune(r) })
	if i < 0 {
		return s
	}
	_, size := utf8.DecodeRuneInString(s[i:])
	return s[i+size:]
}

func wordAfter(s string) string {
	s = strings.TrimLeftFunc(s, unicode.IsSpace)
	end := strings.IndexFunc(s, func(r rune) bool { return !isWordRune(r) })
	if end < 0 {
		return s
	}
	return s[:end]
}
