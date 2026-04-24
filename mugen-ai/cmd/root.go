package cmd

import (
	"os"

	"github.com/spf13/cobra"
)

var rootCmd = &cobra.Command{
	Use:   "mugen-ai",
	Short: "Local AI assistant for mugen-shell",
	Long:  "mugen-ai is a local AI assistant powered by Ollama, designed to integrate with mugen-shell.",
}

func Execute() {
	if err := rootCmd.Execute(); err != nil {
		os.Exit(1)
	}
}
