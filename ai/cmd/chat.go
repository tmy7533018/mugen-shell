package cmd

import (
	"bufio"
	"context"
	"fmt"
	"os"
	"strings"

	"github.com/spf13/cobra"
	"github.com/tmy7533018/mugen-ai/internal/config"
	ctxinfo "github.com/tmy7533018/mugen-ai/internal/context"
	"github.com/tmy7533018/mugen-ai/internal/history"
	"github.com/tmy7533018/mugen-ai/internal/provider"
	"github.com/tmy7533018/mugen-ai/internal/state"
)

var chatCmd = &cobra.Command{
	Use:   "chat",
	Short: "Interactive chat in the terminal",
	RunE:  runChat,
}

var (
	chatModel  string
	chatSystem string
)

func init() {
	rootCmd.AddCommand(chatCmd)
	chatCmd.Flags().StringVarP(&chatModel, "model", "m", "", "model to use (overrides config)")
	chatCmd.Flags().StringVar(&chatSystem, "system", "", "System prompt (overrides config)")
}

func runChat(_ *cobra.Command, _ []string) error {
	cfg, err := config.Load()
	if err != nil {
		fmt.Fprintf(os.Stderr, "warning: config load failed, using defaults: %v\n", err)
		cfg = config.Default()
	}

	model := chatModel
	if model == "" {
		model = state.LoadModel()
	}
	system := chatSystem
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
	scanner := bufio.NewScanner(os.Stdin)

	fmt.Printf("Chat with %s  (commands: exit, clear)\n\n", model)

	for {
		fmt.Print("> ")
		if !scanner.Scan() {
			break
		}
		input := strings.TrimSpace(scanner.Text())
		if input == "" {
			continue
		}
		switch input {
		case "exit":
			return nil
		case "clear":
			hist.Clear()
			fmt.Println("History cleared.")
			continue
		}

		hist.Add("user", input)

		var fullResponse string
		err := registry.Chat(context.Background(), hist.Messages(), func(chunk provider.ChatChunk) error {
			fmt.Print(chunk.Content)
			fullResponse += chunk.Content
			return nil
		})
		fmt.Println()

		if err != nil {
			fmt.Fprintf(os.Stderr, "error: %v\n", err)
			hist.Clear()
			continue
		}

		hist.Add("assistant", fullResponse)
	}

	return nil
}
