package provider

import (
	"context"
	"fmt"
	"sync"
	"time"
)

// providerProbeTimeout bounds each provider's model-listing probe so a hung
// backend (e.g. an Ollama daemon accepting connections but never replying)
// can't stall model resolution for a chat routed to a different provider.
const providerProbeTimeout = 5 * time.Second

type Registry struct {
	mu        sync.RWMutex
	providers []Provider
	model     string
}

func NewRegistry(model string, providers ...Provider) *Registry {
	return &Registry{model: model, providers: providers}
}

func (r *Registry) SetModel(model string) {
	r.mu.Lock()
	defer r.mu.Unlock()
	r.model = model
}

func (r *Registry) Model() string {
	r.mu.RLock()
	defer r.mu.RUnlock()
	return r.model
}

func (r *Registry) Chat(ctx context.Context, messages []Message, opts ChatOptions, fn func(ChatChunk) error) error {
	return r.ChatWith(ctx, r.Model(), messages, opts, fn)
}

// ChatWith routes a chat through the explicit model, bypassing the registry's
// stored default. Used by /chat to honour each conversation's bound model.
func (r *Registry) ChatWith(ctx context.Context, model string, messages []Message, opts ChatOptions, fn func(ChatChunk) error) error {
	p, err := r.providerFor(ctx, model)
	if err != nil {
		return err
	}
	return p.Chat(ctx, model, messages, opts, fn)
}

func (r *Registry) Models(ctx context.Context) ([]string, error) {
	var all []string
	for _, p := range r.providers {
		models, err := probeModels(ctx, p)
		if err != nil {
			continue
		}
		all = append(all, models...)
	}
	return all, nil
}

// probeModels lists a provider's models under a bounded timeout so one
// unresponsive backend can't hang model resolution for the others.
func probeModels(ctx context.Context, p Provider) ([]string, error) {
	probeCtx, cancel := context.WithTimeout(ctx, providerProbeTimeout)
	defer cancel()
	return p.Models(probeCtx)
}

func (r *Registry) Ping(ctx context.Context) bool {
	p, err := r.providerFor(ctx, r.Model())
	if err != nil {
		return false
	}
	return p.Ping(ctx)
}

func (r *Registry) providerFor(ctx context.Context, model string) (Provider, error) {
	if model == "" {
		return nil, fmt.Errorf("no model configured")
	}
	for _, p := range r.providers {
		models, err := probeModels(ctx, p)
		if err != nil {
			continue
		}
		for _, m := range models {
			if m == model {
				return p, nil
			}
		}
	}
	return nil, fmt.Errorf("no provider found for model %q", model)
}
