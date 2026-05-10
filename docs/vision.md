# Vision: tmux-alerts

## The Problem

Running multiple Claude Code CLI sessions in parallel is a force multiplier — four sessions working simultaneously means four times the throughput. But Claude isn't fully autonomous. It hits decision points: missing context, ambiguous specs, tool permission prompts, or tasks that need a human call. When that happens in one of four tmux panes, there's no signal. You either miss it or you babysit the terminal.

The goal is to eliminate babysitting without sacrificing parallelism.

## The Solution

A lightweight local notification system that watches all Claude Code sessions and calls you back only when you're needed. Think of it as a pager for your AI workforce.

```
4 tmux panes running Claude Code
         ↓ (hooks fire on stop / notification events)
  local HTTP server (C# / ASP.NET Core)
         ↓ (WebSocket push)
  browser dashboard (always-open tab)
         ↓ (sound + visual alert)
         YOU
         ↓ (click Jump)
  terminal switches to the right pane
```

## The Experience

1. You open four tmux panes. Each runs `claude` on a different project.
2. You open the dashboard in a browser tab and leave it.
3. You go do something else — review a PR, write an email, make coffee.
4. A sound plays. The dashboard lights up: *"Session 3 — waiting for input: which database should I use?"*
5. You click **Jump**. Your terminal switches directly to that pane.
6. You answer. Claude continues. You walk away again.

That's it. No polling, no checking. Claude calls you, not the other way around.

## What It Is Not

- Not a Claude API wrapper or proxy
- Not a multi-agent orchestrator
- Not a task manager or project dashboard
- Not a way to send messages *back* to Claude from the dashboard (not yet possible without dispatch)
- Not cloud-based, not a SaaS — runs entirely on your machine

## Platform

- **Mac first:** tmux, Claude Code CLI, ASP.NET Core server, browser dashboard
- **WSL later:** same architecture, same server, same hooks — different tmux target syntax

## Design Philosophy

Simple. Elegant. Serves the work, doesn't get in the way of it. No frameworks where none are needed. No patterns for their own sake. The goal is maximum Claude productivity with minimum tooling overhead.
