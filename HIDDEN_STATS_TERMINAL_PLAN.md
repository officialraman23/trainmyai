# Hidden Stats Terminal Plan

## Goal
Use two separate terminal sessions:
1. Visible terminal for the user
2. Hidden terminal for app automation and metrics

## Visible Terminal
- User sees commands and output
- SSH connect from top bar
- AI Trainer sends visible commands here

## Hidden Terminal
- Auto-connects using the same saved SSH command
- Never shown to the user
- Runs:
  - nvidia-smi polling
  - later training log parsing
  - later checkpoint/test monitoring

## Why this is better
- no visible terminal spam
- cleaner parsing
- no PTY mismatch from one-off Process hacks
- easier to add:
  - GPU
  - VRAM
  - temp
  - power
  - loss
  - grad_norm
  - epoch
  - progress

## Next implementation
- build a hidden stats service/session
- auto-start after user clicks Connect
- bind hidden output to top meters
