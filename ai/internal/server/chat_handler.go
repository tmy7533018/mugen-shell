package server

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"os"
	"strings"
	"time"

	"github.com/tmy7533018/mugen-ai/internal/attach"
	"github.com/tmy7533018/mugen-ai/internal/history"
	"github.com/tmy7533018/mugen-ai/internal/provider"
	"github.com/tmy7533018/mugen-ai/internal/store"
	"github.com/tmy7533018/mugen-ai/internal/tools"
)

type chatRequest struct {
	Message        string `json:"message"`
	ConversationID int64  `json:"conversation_id"`
	// Absolute paths; the bytes are read here rather than sent.
	Attachments []string `json:"attachments,omitempty"`
	// Rebinds the conversation's row when it differs from the bound model.
	Model string `json:"model,omitempty"`
	// Pointer so absent and explicit-false stay distinguishable.
	Thinking *bool `json:"thinking,omitempty"`
}

// Returns request-local copies so a concurrent conversation switch can't retarget this turn.
func (s *Server) beginChatTurn(req chatRequest) (convID int64, model string, thinking bool, msgs []provider.Message, status int, err error) {
	s.chatSetupMu.Lock()
	defer s.chatSetupMu.Unlock()

	if err = s.history.Switch(req.ConversationID); err != nil {
		return 0, "", false, nil, http.StatusBadRequest, err
	}

	att, err := attach.Load(req.Attachments)
	if err != nil {
		return 0, "", false, nil, http.StatusBadRequest, err
	}

	model = s.history.ConvModel()
	if req.Model != "" && req.Model != model {
		model = req.Model
		if err = s.history.SetConvModel(model); err != nil {
			return 0, "", false, nil, http.StatusInternalServerError, err
		}
	}
	if model == "" {
		model = s.registry.Model()
	}
	if model == "" {
		return 0, "", false, nil, http.StatusServiceUnavailable, fmt.Errorf("no model configured")
	}

	thinking = s.history.ConvThinking()
	if req.Thinking != nil {
		thinking = *req.Thinking
		if s.history.ConvID() != 0 {
			if err = s.history.SetConvThinking(thinking); err != nil {
				return 0, "", false, nil, http.StatusInternalServerError, err
			}
		}
	}
	if err = s.history.AddWithAttachments("user", req.Message, model, thinking, req.Attachments, att); err != nil {
		return 0, "", false, nil, http.StatusInternalServerError, err
	}

	return s.history.ConvID(), model, thinking, s.history.Messages(), 0, nil
}

func (s *Server) handleChat(w http.ResponseWriter, r *http.Request) {
	r.Body = http.MaxBytesReader(w, r.Body, maxRequestBody)

	var req chatRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil ||
		(req.Message == "" && len(req.Attachments) == 0) {
		http.Error(w, "invalid request", http.StatusBadRequest)
		return
	}

	// Outside chatSetupMu: an uncached probe can take seconds and would serialize turns.
	if req.Model != "" && s.registry.ProviderNameFor(r.Context(), req.Model) == "" {
		http.Error(w, fmt.Sprintf("no provider is serving %q right now", req.Model), http.StatusBadRequest)
		return
	}

	s.registry.EnsureModel(r.Context())

	convID, model, thinking, msgs, status, err := s.beginChatTurn(req)
	if err != nil {
		http.Error(w, err.Error(), status)
		return
	}
	// [system, user] and nothing else means this turn opened the conversation.
	isFirstExchange := len(msgs) == 2

	// Memories ride in the system message: they change rarely, so prompt caches stay warm.
	if blk := s.tools.MemoryBlock(); blk != "" && len(msgs) > 0 && msgs[0].Role == "system" {
		msgs[0].Content += "\n\n" + blk
	}

	s.events.broadcast("conversations", nil)
	s.events.broadcast("messages", map[string]any{"conversation_id": convID})

	w.Header().Set("Content-Type", "text/event-stream")
	w.Header().Set("Cache-Control", "no-cache")
	w.Header().Set("Connection", "keep-alive")

	flusher, ok := w.(http.Flusher)
	if !ok {
		http.Error(w, "streaming not supported", http.StatusInternalServerError)
		return
	}

	// Sent up front: rapid follow-ups otherwise race on the not-yet-loaded conversation id.
	idData, _ := json.Marshal(map[string]any{
		"conversation_id": convID,
		"model":           model,
	})
	fmt.Fprintf(w, "data: %s\n\n", idData)
	flusher.Flush()

	providerName := s.registry.ProviderNameFor(r.Context(), model)
	if providerName != "ollama" {
		history.WithholdLocalResults(msgs)
	}

	// Behind the persona, an attachment with no prompt reads as "nothing was asked".
	if last := len(msgs) - 1; last >= 0 && req.Message == "" && len(req.Attachments) > 0 {
		ask := "Describe what is attached."
		if len(msgs[last].Images) > 0 && len(msgs[last].Content) == 0 {
			ask = "Describe the attached image."
		}
		msgs[last].Content = ask + "\n\n" + msgs[last].Content
	}

	// Never persisted — stale snapshots would pile up and break prompt-cache prefix stability.
	if s.ctxCfg.DesktopState && len(msgs) > 0 &&
		(s.ctxCfg.DesktopStateRemote || providerName == "ollama") {
		if blk := s.tools.DesktopContext(r.Context()); blk != "" {
			last := len(msgs) - 1
			msgs[last].Content = blk + "\n\n" + msgs[last].Content
		}
	}

	gate := s.tools.ChatGate(req.Message)

	const maxIterations = 5
	allTools := s.tools.List()
	selTools := allTools
	if s.filter != nil && (providerName == "ollama" || s.filterRemote) {
		var reason string
		selTools, reason = s.filter.Select(r.Context(), req.Message, s.recent.get(convID), allTools)
		if len(selTools) != len(allTools) {
			fmt.Fprintf(os.Stderr, "toolfilter: %d/%d tools (%s)\n", len(selTools), len(allTools), reason)
		}
	}
	// Only the first request is filtered: a later chain step may need an unhinted category.
	firstTools := ProviderTools(selTools)
	fullTools := firstTools
	if len(selTools) != len(allTools) {
		fullTools = ProviderTools(allTools)
	}
	opts := provider.ChatOptions{Tools: firstTools, Thinking: thinking}

	sendEvent := func(payload map[string]any) {
		data, _ := json.Marshal(payload)
		fmt.Fprintf(w, "data: %s\n\n", data)
		flusher.Flush()
	}

	var fullResponse string
	var turnToolCalls []history.ToolRecord
	// Once content has streamed or a tool fired, the user message can no longer be dropped.
	var sideEffected bool

	persistOnError := func(errMsg string) {
		if sideEffected {
			_ = s.history.AddAssistantTo(convID, history.MarkInterrupted(fullResponse), history.EncodeToolRecords(turnToolCalls))
			s.events.broadcast("conversations", nil)
			s.events.broadcast("messages", map[string]any{"conversation_id": convID})
		} else {
			s.history.RemoveLastFrom(convID)
			// A client that read the conversation back before the rollback still shows the message.
			s.events.broadcast("messages", map[string]any{"conversation_id": convID})
		}
		sendEvent(map[string]any{"error": errMsg, "done": true})
	}

	thinkingSent := false
	for iteration := 0; iteration < maxIterations; iteration++ {
		if iteration == 1 {
			opts.Tools = fullTools
		}
		iterThinkingSent := false
		var iterContent string
		var iterToolCalls []provider.ToolCall

		err := s.registry.ChatWith(r.Context(), model, msgs, opts, func(chunk provider.ChatChunk) error {
			// Deliberately not sideEffected: reasoning alone is not a reply worth persisting.
			if chunk.ThinkingDelta != "" {
				delta := chunk.ThinkingDelta
				// The client appends every iteration's thinking to one bubble.
				if thinkingSent && !iterThinkingSent {
					delta = "\n\n" + delta
				}
				thinkingSent, iterThinkingSent = true, true
				sendEvent(map[string]any{"thinking": delta})
			}
			// A chunk read after the client left was never shown, so it must not keep the turn or run tools.
			if chunk.Content != "" || len(chunk.ToolCalls) > 0 {
				if err := r.Context().Err(); err != nil {
					return err
				}
			}
			if chunk.Content != "" {
				iterContent += chunk.Content
				fullResponse += chunk.Content
				sideEffected = true
				sendEvent(map[string]any{"content": chunk.Content})
			}
			if chunk.Done {
				iterToolCalls = chunk.ToolCalls
			}
			return nil
		})

		if err != nil {
			persistOnError(err.Error())
			return
		}

		if len(iterToolCalls) == 0 {
			// Tool calls already had their side effects, so an empty final answer still needs a row.
			if fullResponse != "" || len(turnToolCalls) > 0 {
				_ = s.history.AddAssistantTo(convID, fullResponse, history.EncodeToolRecords(turnToolCalls))
				s.events.broadcast("conversations", nil)
				s.events.broadcast("messages", map[string]any{"conversation_id": convID})
				if isFirstExchange && fullResponse != "" {
					go s.generateTitle(convID, model, req.Message, fullResponse)
				}
			}
			sendEvent(map[string]any{"done": true})
			return
		}

		msgs = append(msgs, provider.Message{
			Role:      "assistant",
			Content:   iterContent,
			ToolCalls: iterToolCalls,
		})

		firstOfIter := len(turnToolCalls)
		for _, tc := range iterToolCalls {
			turnToolCalls = append(turnToolCalls, history.ToolRecord{ToolCall: tc, Provider: providerName})
		}
		sendEvent(map[string]any{"tool_calls": iterToolCalls})

		for i, tc := range iterToolCalls {
			// Noted even for denied or failed calls, so follow-ups keep the same tools visible.
			s.recent.note(convID, tools.CategoryOf(tc.Name))

			var result string
			var callErr error
			approved, answered := true, true
			if gate.Needs(tc.Name) {
				approved, answered = s.awaitConfirm(r.Context(), tc, sendEvent)
			}
			// A denial is fed back as an ordinary result, without the action having happened.
			switch {
			// A native tool can ignore its context, and a gated call above may be how the client left.
			case r.Context().Err() != nil:
				result = "error: the client left before this action ran, so it did not run. Tell the user it was not done; call it again only if they ask again."
				s.tools.Audit(tc.Name, tc.Arguments, result, nil)
			case approved:
				result, callErr = s.tools.Call(r.Context(), tc.Name, tc.Arguments)
			case answered:
				result = "error: the user declined this action. Do not retry it; acknowledge their choice and move on."
				s.tools.Audit(tc.Name, tc.Arguments, result, nil)
			default:
				result = "error: the approval prompt expired or was closed before the user answered, so this action did not run. Tell the user it was not done; call it again only if they ask again."
				s.tools.Audit(tc.Name, tc.Arguments, result, nil)
			}
			sideEffected = true
			resultPayload := tools.ResultPayload(result, callErr)
			turnToolCalls[firstOfIter+i].Result = resultPayload
			turnToolCalls[firstOfIter+i].Error = errString(callErr)

			sendEvent(map[string]any{
				"tool_result": map[string]any{
					"id":     tc.ID,
					"name":   tc.Name,
					"result": resultPayload,
					"error":  errString(callErr),
				},
			})

			msgs = append(msgs, provider.Message{
				Role:       "tool",
				ToolCallID: tc.ID,
				ToolName:   tc.Name,
				Content:    resultPayload,
			})
		}
	}

	persistOnError("max tool iterations exceeded")
}

// Best-effort: any failure leaves the fallback title in place.
func (s *Server) generateTitle(convID int64, model, userMsg, reply string) {
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	prompt := "Write a title for this conversation: 2-5 words, in the same language as the exchange. Reply with ONLY the title — no quotes, no trailing punctuation.\n\nUser: " +
		firstN(userMsg, 400) + "\nAssistant: " + firstN(reply, 400)
	var title string
	err := s.registry.ChatWith(ctx, model, []provider.Message{{Role: "user", Content: prompt}},
		provider.ChatOptions{}, func(c provider.ChatChunk) error {
			title += c.Content
			return nil
		})
	if err != nil {
		return
	}
	// Some local models leak a reasoning block despite think=false.
	if i := strings.Index(title, "</think>"); i >= 0 {
		title = title[i+len("</think>"):]
	}
	if i := strings.IndexByte(title, '\n'); i >= 0 {
		title = title[:i]
	}
	title = strings.Trim(strings.TrimSpace(title), `"'「」『』.。`)
	if title == "" {
		return
	}
	if err := s.store.UpdateConversationTitle(convID, store.DeriveTitle(title)); err == nil {
		s.events.broadcast("conversations", nil)
	}
}

func firstN(s string, n int) string {
	rs := []rune(s)
	if len(rs) <= n {
		return s
	}
	return string(rs[:n]) + "…"
}

// A timeout or disconnect never runs the tool, but is reported as unanswered rather than declined.
func (s *Server) awaitConfirm(ctx context.Context, tc provider.ToolCall, send func(map[string]any)) (approved, answered bool) {
	id, ch := s.confirms.register()
	defer s.confirms.discard(id)

	payload := map[string]any{
		"confirm_id": id,
		"name":       tc.Name,
		"arguments":  tc.Arguments,
		"expires_at": time.Now().Add(confirmTimeout).UnixMilli(),
	}
	if t := s.tools.ConfirmTarget(tc.Name, tc.Arguments); t != "" {
		payload["target"] = t
	}
	send(map[string]any{"tool_confirm": payload})

	select {
	case approved := <-ch:
		return approved, true
	case <-time.After(confirmTimeout):
		return false, false
	case <-ctx.Done():
		return false, false
	}
}

type chatConfirmRequest struct {
	ConfirmID string `json:"confirm_id"`
	Approved  bool   `json:"approved"`
}

func (s *Server) handleChatConfirm(w http.ResponseWriter, r *http.Request) {
	r.Body = http.MaxBytesReader(w, r.Body, maxRequestBody)
	var req chatConfirmRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil || req.ConfirmID == "" {
		http.Error(w, "invalid request", http.StatusBadRequest)
		return
	}
	if !s.confirms.resolve(req.ConfirmID, req.Approved) {
		http.Error(w, "no such pending confirmation", http.StatusNotFound)
		return
	}
	writeJSON(w, map[string]any{"resolved": true})
}

func errString(err error) string {
	if err == nil {
		return ""
	}
	return err.Error()
}
