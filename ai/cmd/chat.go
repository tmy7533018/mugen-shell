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
	"github.com/tmy7533018/mugen-ai/internal/store"
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

	st, err := store.Open(historyDBPath())
	if err != nil {
		return fmt.Errorf("open history store: %w", err)
	}
	defer st.Close()

	hist, err := history.New(st, system)
	if err != nil {
		return fmt.Errorf("init history: %w", err)
	}
	hist.ContextFunc = func() string { return ctxinfo.Build(cfg.Context) }
	scanner := bufio.NewScanner(os.Stdin)

	fmt.Printf("Chat with %s  (commands: exit, new)\n\n", model)

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
		case "new", "clear":
			if _, err := hist.NewConversation(registry.Model()); err != nil {
				fmt.Fprintf(os.Stderr, "error: %v\n", err)
			} else {
				fmt.Println("Started a new conversation.")
			}
			continue
		}

		if err := hist.Add("user", input, registry.Model()); err != nil {
			fmt.Fprintf(os.Stderr, "error: %v\n", err)
			continue
		}

		var fullResponse string
		err := registry.Chat(context.Background(), hist.Messages(), func(chunk provider.ChatChunk) error {
			fmt.Print(chunk.Content)
			fullResponse += chunk.Content
			return nil
		})
		fmt.Println()

		if err != nil {
			fmt.Fprintf(os.Stderr, "error: %v\n", err)
			hist.RemoveLast()
			continue
		}

		_ = hist.Add("assistant", fullResponse, registry.Model())
	}

	return nil
}
