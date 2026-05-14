package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"strings"
)

func queuePath() (string, error) {
	root, err := projectRoot()
	if err != nil {
		return "", err
	}
	stateDir := os.Getenv("XDG_STATE_HOME")
	if stateDir == "" {
		home, _ := os.UserHomeDir()
		stateDir = filepath.Join(home, ".local", "state")
	}
	hash := rootHash(root)
	return filepath.Join(stateDir, "cairn", "queue-"+hash+".jsonl"), nil
}

type pairEntry struct {
	Timestamp  int64  `json:"timestamp"`
	File       string `json:"file"`
	CursorLine int    `json:"cursor_line"`
	Diff       string `json:"diff"`
}

func runDrainQueue() error {
	_, _ = io.ReadAll(os.Stdin)

	qp, err := queuePath()
	if err != nil {
		return emitEmpty()
	}

	data, err := os.ReadFile(qp)
	if err != nil || len(bytes.TrimSpace(data)) == 0 {
		return emitEmpty()
	}

	if err := os.Truncate(qp, 0); err != nil {
		return emitEmpty()
	}

	var entries []pairEntry
	for _, line := range bytes.Split(data, []byte("\n")) {
		if len(bytes.TrimSpace(line)) == 0 {
			continue
		}
		var entry pairEntry
		if err := json.Unmarshal(line, &entry); err != nil {
			continue
		}
		entries = append(entries, entry)
	}

	if len(entries) == 0 {
		return emitEmpty()
	}

	var sb strings.Builder
	sb.WriteString("Since your last message, the user saved file(s) in their Neovim editor. ")
	sb.WriteString("These are the diffs between the prior state and what they just saved:\n\n")
	for _, e := range entries {
		fmt.Fprintf(&sb, "## %s (cursor at line %d)\n```diff\n%s\n```\n\n", e.File, e.CursorLine, e.Diff)
	}

	out := map[string]any{
		"hookSpecificOutput": map[string]any{
			"hookEventName":     "UserPromptSubmit",
			"additionalContext": sb.String(),
		},
	}
	return json.NewEncoder(os.Stdout).Encode(out)
}

func emitEmpty() error {
	out := map[string]any{
		"hookSpecificOutput": map[string]any{
			"hookEventName":     "UserPromptSubmit",
			"additionalContext": "",
		},
	}
	return json.NewEncoder(os.Stdout).Encode(out)
}
