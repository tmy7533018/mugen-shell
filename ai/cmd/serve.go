package cmd

import (
	"context"
	"fmt"
	"net/http"
	"os"
	"os/signal"
	"strconv"
	"syscall"
	"time"

	"github.com/spf13/cobra"
	"github.com/tmy7533018/mugen-ai/internal/server"
)

// defaultPort is the port mugen-ai listens on when neither the --port flag
// nor MUGEN_AI_PORT env var is set. The shell client (shell/lib/AiBackend.qml)
// uses the same fallback.
const defaultPort = 11435

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
	// Resolve the default port: --port flag wins; otherwise honour
	// MUGEN_AI_PORT (lets the systemd EnvironmentFile keep backend +
	// shell client in sync); fall back to the constant.
	def := defaultPort
	if v, ok := os.LookupEnv("MUGEN_AI_PORT"); ok {
		if n, err := strconv.Atoi(v); err == nil && n > 0 {
			def = n
		}
	}
	serveCmd.Flags().IntVarP(&servePort, "port", "p", def, "port to listen on")
	serveCmd.Flags().StringVarP(&serveModel, "model", "m", "", "model to use on startup (overrides config)")
	serveCmd.Flags().StringVar(&serveSystem, "system", "", "System prompt (overrides config)")
}

func runServe(_ *cobra.Command, _ []string) error {
	rt, err := loadRuntimeContext(serveModel, serveSystem)
	if err != nil {
		return err
	}
	defer rt.Store.Close()

	srv := server.New(rt.Registry, rt.History, rt.Store)

	addr := fmt.Sprintf("127.0.0.1:%d", servePort)
	httpSrv := &http.Server{Addr: addr, Handler: srv.Routes()}

	done := make(chan error, 1)
	go func() { done <- httpSrv.ListenAndServe() }()

	fmt.Fprintf(os.Stdout, "mugen-ai listening on %s (model: %s)\n", addr, rt.Model)

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
