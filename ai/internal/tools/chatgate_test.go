package tools

import "testing"

func TestMentionsMemoryIntent(t *testing.T) {
	for _, s := range []string{
		"覚えて", "覚えておいて", "これ覚えといて", "好みを記憶してね", "記憶しといて", "メモしておいて", "メモしといて",
		"メモっといて", "覚えてください", "覚えてね！", "忘れないでね", "忘れずに伝えて", "おぼえてて", "おぼえといて",
		"わすれないでね", "わすれずに",
		"Remember I like tea", "REMEMBER this", "ＲＥＭＥＭＢＥＲ this", "please memorize it", "Memorise that",
		"Hey, remember this", "remember, I like tea", "I want you to remember my birthday",
		"Don't forget the milk", "Don’t forget the milk", "dont forget", "DO NOT FORGET",
		"keep in mind I'm vegan", "Note that I use neovim", "From now on reply in French",
		"save this to your memory", "add it to memory", "keep that in your memory",
	} {
		if !mentionsMemoryIntent(s) {
			t.Errorf("mentionsMemoryIntent(%q) = false, want true", s)
		}
	}
}

func TestMentionsMemoryIntentIgnoresQuestionsAndStatements(t *testing.T) {
	for _, s := range []string{
		"", "今日の天気は？", "音量を上げて", "what is the volume", "forget it", "忘れてください", "notes", "mind the gap",
		"覚えてる？", "覚えてない", "覚えていますか", "それ覚えてた？", "覚えてます", "覚えてらっしゃる？", "覚えてん",
		"おぼえてる？", "記憶してる？", "メモしてた？", "覚えとる", "覚えとった", "おぼえとる",
		"今後はどうなるの？", "これからはじめよう", "今後は気をつける", "これからは",
		"do you remember my name?", "she did not remember", "did you remember the milk", "I don't remember where I put it",
		"I dont remember", "I can't remember", "I cannot remember", "I do not remember", "never remember",
		"remember when we met", "remembered", "remembering", "memorized?", "memorizing",
		"Does he remember?", "I didn't remember", "I couldn't remember", "I won't remember", "I remember that",
		"we remember it", "they'd say I can remember", "will remember",
		"the keynote that Apple gave", "into memory", "from memory", "in memory",
	} {
		if mentionsMemoryIntent(s) {
			t.Errorf("mentionsMemoryIntent(%q) = true, want false", s)
		}
	}
}

func TestChatGateLetsOneAskedForSaveRunPerTurn(t *testing.T) {
	r, _ := newMemoryRegistry(t, nil)
	g := r.ChatGate("覚えといて: I like tea")

	for i, want := range []bool{false, true, true} {
		if got := g.Needs("memory_save"); got != want {
			t.Errorf("memory_save #%d: Needs = %v, want %v", i+1, got, want)
		}
	}
	if r.ChatGate("remember this").Needs("memory_save") {
		t.Error("a new turn must start with its own free save")
	}
}

func TestChatGateAsksForEverySaveNobodyRequested(t *testing.T) {
	r, _ := newMemoryRegistry(t, nil)
	for _, text := range []string{"what's the weather", "覚えてる？", ""} {
		g := r.ChatGate(text)
		for i := 0; i < 2; i++ {
			if !g.Needs("memory_save") {
				t.Errorf("%q: memory_save #%d ran unasked", text, i+1)
			}
		}
	}
}

func TestChatGateOnlySpendsTheFreeSaveOnMemorySave(t *testing.T) {
	r, _ := newMemoryRegistry(t, nil)
	g := r.ChatGate("覚えといて")

	for tool, want := range map[string]bool{
		"memory_delete": true, "calendar_delete": true, "notification_clear_all": true,
		"audio_set_volume": false, "memory_list": false, "no_such_tool": false,
	} {
		if got := g.Needs(tool); got != want {
			t.Errorf("%s: Needs = %v, want %v", tool, got, want)
		}
	}
	if g.Needs("memory_save") {
		t.Error("other calls must not use up the free save")
	}
}

func TestChatGateSkipsToolsInADisabledCategory(t *testing.T) {
	r, _ := newMemoryRegistry(t, []string{"memory", "calendar"})
	g := r.ChatGate("覚えといて")

	for _, tool := range []string{"memory_delete", "memory_save", "calendar_delete"} {
		if g.Needs(tool) {
			t.Errorf("%s: a card for a call that will be refused anyway", tool)
		}
	}
	if !g.Needs("notification_clear_all") {
		t.Error("a gated tool in an enabled category must still wait")
	}
}

func TestChatGateIgnoresMemorySaveWhenMemoryIsNotAttached(t *testing.T) {
	r, _, _ := newTestRegistry(t, nil, nil)
	if r.ChatGate("hello").Needs("memory_save") {
		t.Error("memory_save is not registered, so there is nothing to hold")
	}
}
