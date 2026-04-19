# Terminal Controller Refactor

## Goal
Use the SAME working SwiftTerm session for:
- visible user terminal
- hidden background command execution
- output parsing for GPU/training metrics

## Why
Current issues:
- second/background SSH path fails with RunPod PTY behavior
- visible terminal gets noisy if hidden commands are injected directly
- metrics cannot be reliably read without a shared output controller

## Requirements
1. Shared terminal controller object
2. SwiftTerm view registers itself with controller
3. Controller can:
   - send visible commands
   - send hidden tagged commands
   - capture output stream
   - parse tagged metrics blocks
4. UI only shows user-facing terminal output
5. Metrics strip updates separately

## Hidden command strategy
Use tagged markers:
__TRAINMYAI_STATS_START__
cat /tmp/trainmyai/gpu_stats.txt
__TRAINMYAI_STATS_END__

Controller parses only content between markers.

## Later extension
Same approach for:
- loss
- grad_norm
- step
- epoch
- progress percentage
