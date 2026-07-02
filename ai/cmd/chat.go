package cmd

import (
	"bufio"
	"context"
	"encoding/json"
	"fmt"
	"os"
	"strings"

	"github.com/spf13/cobra"
	"github.com/tmy7533018/mugen-ai/internal/provider"
	"github.com/tmy7533018/mugen-ai/internal/tools"
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
	defer rt.MCP.Close()

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
			if _, err := rt.History.NewConversation(rt.Registry.Model(), false); err != nil {
				fmt.Fprintf(os.Stderr, "error: %v\n", err)
			} else {
				fmt.Println("Started a new conversation.")
			}
			continue
		}

		if err := rt.History.Add("user", input, rt.Registry.Model(), false); err != nil {
			fmt.Fprintf(os.Stderr, "error: %v\n", err)
			continue
		}

		msgs := rt.History.Messages()
		// Same injections as the HTTP server: memories inside the system
		// message, desktop state in front of the newest user message.
		if blk := rt.Tools.MemoryBlock(); blk != "" && len(msgs) > 0 && msgs[0].Role == "system" {
			msgs[0].Content += "\n\n" + blk
		}
		if rt.Cfg.Context.DesktopState && len(msgs) > 0 &&
			(rt.Cfg.Context.DesktopStateRemote || rt.Registry.ProviderNameFor(context.Background(), rt.Registry.Model()) == "ollama") {
			if blk := rt.Tools.DesktopContext(context.Background()); blk != "" {
				userMsg := msgs[len(msgs)-1]
				msgs = append(msgs[:len(msgs)-1:len(msgs)-1],
					provider.Message{Role: "system", Content: blk}, userMsg)
			}
		}

		fullResponse, err := runChatTurn(rt, scanner, msgs)
		fmt.Println()

		if err != nil {
			fmt.Fprintf(os.Stderr, "error: %v\n", err)
			// Persist whatever already streamed; dropping only the user
			// message would leave two consecutive user turns in history.
			if fullResponse == "" {
				rt.History.RemoveLast()
			} else {
				_ = rt.History.Add("assistant", fullResponse, rt.Registry.Model(), false)
			}
			continue
		}

		_ = rt.History.Add("assistant", fullResponse, rt.Registry.Model(), false)
	}

	return nil
}

// runChatTurn streams one turn including the tool-call loop — the terminal
// twin of the server's handleChat. Confirm-gated tools prompt on stdin.
func runChatTurn(rt *runtimeContext, scanner *bufio.Scanner, msgs []provider.Message) (string, error) {
	const maxIterations = 5
	opts := provider.ChatOptions{Tools: cliProviderTools(rt.Tools.List())}
	ctx := context.Background()

	var fullResponse string
	for iteration := 0; iteration < maxIterations; iteration++ {
		var iterContent string
		var iterToolCalls []provider.ToolCall

		err := rt.Registry.Chat(ctx, msgs, opts, func(chunk provider.ChatChunk) error {
			fmt.Print(chunk.Content)
			iterContent += chunk.Content
			fullResponse += chunk.Content
			if chunk.Done {
				iterToolCalls = chunk.ToolCalls
			}
			return nil
		})
		if err != nil {
			return fullResponse, err
		}
		if len(iterToolCalls) == 0 {
			return fullResponse, nil
		}

		msgs = append(msgs, provider.Message{
			Role:      "assistant",
			Content:   iterContent,
			ToolCalls: iterToolCalls,
		})

		for _, tc := range iterToolCalls {
			var result string
			if rt.Tools.NeedsConfirm(tc.Name) && !cliConfirm(scanner, tc) {
				result = "error: the user declined this action. Do not retry it; acknowledge their choice and move on."
				rt.Tools.Audit(tc.Name, tc.Arguments, result, nil)
			} else {
				res, callErr := rt.Tools.Call(ctx, tc.Name, tc.Arguments)
				result = res
				if callErr != nil {
					result = fmt.Sprintf("error: %v (output: %s)", callErr, res)
				}
				fmt.Printf("\n[tool %s]\n", tc.Name)
			}
			msgs = append(msgs, provider.Message{
				Role:       "tool",
				ToolCallID: tc.ID,
				ToolName:   tc.Name,
				Content:    result,
			})
		}
	}
	return fullResponse, fmt.Errorf("max tool iterations exceeded")
}

// cliConfirm is the terminal stand-in for the GUI approval dialog; EOF or
// anything but y counts as a denial, mirroring the server's deny-by-default.
func cliConfirm(scanner *bufio.Scanner, tc provider.ToolCall) bool {
	args, _ := json.Marshal(tc.Arguments)
	fmt.Printf("\n[confirm] %s %s — approve? [y/N]: ", tc.Name, args)
	if !scanner.Scan() {
		return false
	}
	answer := strings.ToLower(strings.TrimSpace(scanner.Text()))
	return answer == "y" || answer == "yes"
}

func cliProviderTools(in []tools.Tool) []provider.Tool {
	out := make([]provider.Tool, len(in))
	for i, t := range in {
		out[i] = provider.Tool{
			Name:        t.Name,
			Description: t.Description,
			Parameters:  t.Parameters,
		}
	}
	return out
}
