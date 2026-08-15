package cmd

import (
	"fmt"
	"os"

	"github.com/spf13/cobra"
	"github.com/tmy7533018/mugen-ai/internal/art"
)

var artCmd = &cobra.Command{
	Use:   "art",
	Short: "Album art helpers used by the shell's music module",
}

// Prints the fallback colour before failing, so callers need none of their own.
var artColorCmd = &cobra.Command{
	Use:   "color <path>",
	Short: "Print the dominant colour of an image as comma-separated floats",
	Args:  cobra.ExactArgs(1),
	RunE: func(cmd *cobra.Command, args []string) error {
		rgb, err := art.DominantColor(args[0])
		fmt.Printf("%.3f,%.3f,%.3f\n", rgb.R, rgb.G, rgb.B)
		if err != nil {
			fmt.Fprintln(os.Stderr, "art color:", err)
			os.Exit(1)
		}
		return nil
	},
	SilenceUsage: true,
}

var artTrimCmd = &cobra.Command{
	Use:   "trim <path>",
	Short: "Trim letterbox bars from cover art in place",
	Args:  cobra.ExactArgs(1),
	RunE: func(cmd *cobra.Command, args []string) error {
		return art.TrimBars(args[0])
	},
	SilenceUsage: true,
}

func init() {
	artCmd.AddCommand(artColorCmd)
	artCmd.AddCommand(artTrimCmd)
	rootCmd.AddCommand(artCmd)
}
