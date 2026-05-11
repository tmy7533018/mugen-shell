package cmd

import (
	"bufio"
	"context"
	"fmt"
	"os"
	"strings"

	"github.com/spf13/cobra"
	"github.com/tmy7533018/mugen-ai/internal/provider"
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
	rt, err := loadRuntimeContext(chatModel, chatSystem)
	if err != nil {
		return err
	}
	defer rt.Store.Close()

	scanner := bufio.NewScanner(os.Stdin)
	fmt.Printf("Chat with %s  (commands: exit, new)\n\n", rt.Model)

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
			if _, err := rt.History.NewConversation(rt.Registry.Model()); err != nil {
				fmt.Fprintf(os.Stderr, "error: %v\n", err)
			} else {
				fmt.Println("Started a new conversation.")
			}
			continue
		}

		if err := rt.History.Add("user", input, rt.Registry.Model()); err != nil {
			fmt.Fprintf(os.Stderr, "error: %v\n", err)
			continue
		}

		var fullResponse string
		err := rt.Registry.Chat(context.Background(), rt.History.Messages(), provider.ChatOptions{}, func(chunk provider.ChatChunk) error {
			fmt.Print(chunk.Content)
			fullResponse += chunk.Content
			return nil
		})
		fmt.Println()

		if err != nil {
			fmt.Fprintf(os.Stderr, "error: %v\n", err)
			rt.History.RemoveLast()
			continue
		}

		_ = rt.History.Add("assistant", fullResponse, rt.Registry.Model())
	}

	return nil
}
