package cmd

import (
	"bufio"
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
	"strconv"
	"strings"
	"time"

	"github.com/spf13/cobra"
)

// mcpServerCmd bridges a stdio MCP client (Claude Desktop, Cursor, ...) to
// the running daemon's /mcp endpoint. A thin proxy instead of a standalone
// server keeps one tool registry, one SQLite handle, and one audit log — the
// daemon stays the single place shell state is touched from.
var mcpServerCmd = &cobra.Command{
	Use:   "mcp-server",
	Short: "Expose mugen-shell tools to stdio MCP clients via the running daemon",
	Long: `Bridges stdio MCP framing to the mugen-ai daemon's /mcp endpoint.
Point Claude Desktop (or any stdio MCP client) at:

  { "command": "mugen-ai", "args": ["mcp-server"] }

Requires 'mugen-ai serve' to be running with [mcp_expose] enabled = true.`,
	RunE: runMCPServer,
}

var mcpServerPort int

func init() {
	rootCmd.AddCommand(mcpServerCmd)
	def := defaultPort
	if v, ok := os.LookupEnv("MUGEN_AI_PORT"); ok {
		if n, err := strconv.Atoi(v); err == nil && n > 0 {
			def = n
		}
	}
	mcpServerCmd.Flags().IntVarP(&mcpServerPort, "port", "p", def, "daemon port to bridge to")
}

func runMCPServer(_ *cobra.Command, _ []string) error {
	endpoint := fmt.Sprintf("http://127.0.0.1:%d/mcp", mcpServerPort)
	// Generous timeout: a tools/call can sit behind a slow qs IPC round-trip,
	// and MCP clients apply their own deadlines on top.
	client := &http.Client{Timeout: 120 * time.Second}

	in := bufio.NewReaderSize(os.Stdin, 1<<20)
	for {
		line, err := in.ReadBytes('\n')
		if msg := bytes.TrimSpace(line); len(msg) > 0 {
			if resp := bridgeForward(client, endpoint, msg); resp != nil {
				os.Stdout.Write(append(resp, '\n'))
			}
		}
		if err != nil {
			if err == io.EOF {
				return nil // client closed our stdin; normal shutdown
			}
			return err
		}
	}
}

// bridgeForward POSTs one JSON-RPC message to the daemon and returns the
// bytes to write back to the client, nil when nothing is due. Failures reach
// the client as JSON-RPC errors (when the message was a request) so it shows
// a reason instead of hanging.
func bridgeForward(client *http.Client, endpoint string, msg []byte) []byte {
	var probe struct {
		ID     json.RawMessage `json:"id"`
		Method string          `json:"method"`
	}
	_ = json.Unmarshal(msg, &probe)
	isRequest := probe.Method != "" && len(probe.ID) > 0 && string(probe.ID) != "null"

	fail := func(text string) []byte {
		if !isRequest {
			fmt.Fprintf(os.Stderr, "mcp-server: %s\n", text)
			return nil
		}
		out, _ := json.Marshal(map[string]any{
			"jsonrpc": "2.0",
			"id":      probe.ID,
			"error":   map[string]any{"code": -32000, "message": text},
		})
		return out
	}

	resp, err := client.Post(endpoint, "application/json", bytes.NewReader(msg))
	if err != nil {
		return fail(fmt.Sprintf("mugen-ai daemon unreachable at %s — is `mugen-ai serve` running? (%v)", endpoint, err))
	}
	defer resp.Body.Close()
	body, _ := io.ReadAll(io.LimitReader(resp.Body, 4<<20))

	switch resp.StatusCode {
	case http.StatusOK:
		if b := bytes.TrimSpace(body); len(b) > 0 {
			return b
		}
		return nil
	case http.StatusAccepted:
		return nil
	case http.StatusNotFound:
		return fail("MCP expose is disabled — set [mcp_expose] enabled = true in config.toml and restart mugen-ai")
	default:
		return fail(fmt.Sprintf("daemon returned status %d: %s", resp.StatusCode, strings.TrimSpace(string(body))))
	}
}
