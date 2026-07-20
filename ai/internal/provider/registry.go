package provider

import (
	"context"
	"fmt"
	"sync"
	"time"
)

// Bounds each model-listing probe so a hung backend can't stall resolution for
// a chat routed to a different provider.
const providerProbeTimeout = 5 * time.Second

type Registry struct {
	mu        sync.RWMutex
	providers []Provider
	model     string
	// Saves an HTTP round-trip per backend on every turn. A model's owning
	// provider doesn't change at runtime, so entries never need invalidation.
	routeCache map[string]Provider
}

func NewRegistry(model string, providers ...Provider) *Registry {
	return &Registry{model: model, providers: providers, routeCache: map[string]Provider{}}
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
// stored default.
func (r *Registry) ChatWith(ctx context.Context, model string, messages []Message, opts ChatOptions, fn func(ChatChunk) error) error {
	p, err := r.providerFor(ctx, model)
	if err != nil {
		return err
	}
	return p.Chat(ctx, model, messages, opts, fn)
}

// ProviderNameFor reports which provider serves the model ("ollama",
// "anthropic", …), or "" when none claims it.
func (r *Registry) ProviderNameFor(ctx context.Context, model string) string {
	p, err := r.providerFor(ctx, model)
	if err != nil {
		return ""
	}
	return p.Name()
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
	r.mu.RLock()
	cached := r.routeCache[model]
	r.mu.RUnlock()
	if cached != nil {
		return cached, nil
	}
	for _, p := range r.providers {
		models, err := probeModels(ctx, p)
		if err != nil {
			continue
		}
		for _, m := range models {
			if m == model {
				r.mu.Lock()
				r.routeCache[model] = p
				r.mu.Unlock()
				return p, nil
			}
		}
	}
	return nil, fmt.Errorf("no provider found for model %q", model)
}
