# Changelog

## 0.2.0

- Starts in FAST mode; very short prompts in ASK mode are routed to FAST automatically.
- ASK mode skips the judge when the first two answers agree (>= 80% similar).
- A timing line is printed after every result.
- New `/warm on|off` command to toggle the warm opencode server.
- Softer per-agent approach hints so trivial prompts don't trigger repo exploration.
