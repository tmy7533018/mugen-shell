package cmd

import (
	"context"
	"fmt"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/spf13/cobra"
	"github.com/tmy7533018/mugen-ai/internal/config"
	ctxinfo "github.com/tmy7533018/mugen-ai/internal/context"
	"github.com/tmy7533018/mugen-ai/internal/history"
	"github.com/tmy7533018/mugen-ai/internal/provider"
	"github.com/tmy7533018/mugen-ai/internal/server"
	"github.com/tmy7533018/mugen-ai/internal/state"
)

var serveCmd = &cobra.Command{
	Use:   "serve",
	Short: "Start the mugen-ai HTTP server for mugen-shell integration",
	RunE:  runServe,
}

var (
	servePort   int
	serveModel  string
	serveSystem string
)

func init() {
	rootCmd.AddCommand(serveCmd)
	serveCmd.Flags().IntVarP(&servePort, "port", "p", 11435, "port to listen on")
	serveCmd.Flags().StringVarP(&serveModel, "model", "m", "", "model to use on startup (overrides config)")
	serveCmd.Flags().StringVar(&serveSystem, "system", "", "System prompt (overrides config)")
}

func runServe(_ *cobra.Command, _ []string) error {
	cfg, err := config.Load()
	if err != nil {
		fmt.Fprintf(os.Stderr, "warning: config load failed, using defaults: %v\n", err)
		cfg = config.Default()
	}

	model := serveModel
	if model == "" {
		model = state.LoadModel()
	}
	system := serveSystem
	if system == "" {
		system = cfg.Personality.SystemPrompt
	}

	registry := buildRegistry(cfg, model)
	if model == "" {
		if models, _ := registry.Models(context.Background()); len(models) > 0 {
			model = models[0]
			registry.SetModel(model)
		}
	}

	hist := history.New(system)
	hist.ContextFunc = func() string { return ctxinfo.Build(cfg.Context) }
	srv := server.New(registry, hist)

	addr := fmt.Sprintf("127.0.0.1:%d", servePort)
	httpSrv := &http.Server{Addr: addr, Handler: srv.Routes()}

	done := make(chan error, 1)
	go func() { done <- httpSrv.ListenAndServe() }()

	fmt.Fprintf(os.Stdout, "mugen-ai listening on %s (model: %s)\n", addr, model)

	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)

	select {
	case sig := <-quit:
		fmt.Fprintf(os.Stdout, "\nreceived %s, shutting down...\n", sig)
	case err := <-done:
		return err
	}

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	return httpSrv.Shutdown(ctx)
}

func buildRegistry(cfg config.Config, model string) *provider.Registry {
	providers := []provider.Provider{
		provider.NewOllama(cfg.Provider.Ollama.Host),
	}
	if cfg.Provider.Google.Model != "" {
		key := os.Getenv("GEMINI_API_KEY")
		if key == "" {
			key = os.Getenv("GOOGLE_API_KEY")
		}
		if key != "" {
			providers = append(providers, provider.NewGoogle(key, cfg.Provider.Google.Model))
		}
	}
	return provider.NewRegistry(model, providers...)
}
