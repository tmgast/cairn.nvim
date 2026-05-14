package main

import (
	"encoding/json"
	"flag"
	"fmt"
	"os"

	"github.com/mark3labs/mcp-go/server"
)

const version = "0.0.1"

func main() {
	check := flag.Bool("check", false, "Probe the cairn nvim plugin and print status, then exit.")
	call := flag.String("call", "", "Call a plugin method directly. Use with -params for the JSON body.")
	params := flag.String("params", "{}", "JSON params payload for -call.")
	drainQueue := flag.Bool("drain-queue", false, "Drain the pair-mode queue and emit a Claude Code UserPromptSubmit hook payload.")
	flag.Parse()

	if *check {
		if err := runCheck(); err != nil {
			fmt.Fprintln(os.Stderr, "cairn check failed:", err)
			os.Exit(1)
		}
		return
	}

	if *call != "" {
		if err := runCall(*call, *params); err != nil {
			fmt.Fprintln(os.Stderr, "cairn call failed:", err)
			os.Exit(1)
		}
		return
	}

	if *drainQueue {
		if err := runDrainQueue(); err != nil {
			fmt.Fprintln(os.Stderr, "cairn drain failed:", err)
			os.Exit(1)
		}
		return
	}

	s := server.NewMCPServer("cairn", version)
	registerTools(s)

	if err := server.ServeStdio(s); err != nil {
		fmt.Fprintln(os.Stderr, "cairn:", err)
		os.Exit(1)
	}
}

func runCheck() error {
	resp, err := sendRequest("status", map[string]any{})
	if err != nil {
		return err
	}
	b, _ := json.MarshalIndent(resp, "", "  ")
	fmt.Println(string(b))
	return nil
}

func runCall(method, paramsJSON string) error {
	var params map[string]any
	if err := json.Unmarshal([]byte(paramsJSON), &params); err != nil {
		return fmt.Errorf("parse params: %w", err)
	}
	resp, err := sendRequest(method, params)
	if err != nil {
		return err
	}
	b, _ := json.MarshalIndent(resp, "", "  ")
	fmt.Println(string(b))
	return nil
}
