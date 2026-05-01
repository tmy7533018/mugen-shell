package provider

import (
	"context"
	"fmt"
	"sync"
)

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

func (r *Registry) Chat(ctx context.Context, messages []Message, fn func(ChatChunk) error) error {
	model := r.Model()
	p, err := r.providerFor(ctx, model)
	if err != nil {
		return err
	}
	return p.Chat(ctx, model, messages, fn)
}

func (r *Registry) Models(ctx context.Context) ([]string, error) {
	var all []string
	for _, p := range r.providers {
		models, err := p.Models(ctx)
		if err != nil {
			continue
		}
		all = append(all, models...)
	}
	return all, nil
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
		models, err := p.Models(ctx)
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
