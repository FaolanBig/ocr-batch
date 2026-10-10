# Big Batch OCR Script Documentation

This directory contains the technical documentation for the OCR processing workflow implemented in [scr/ocr_sequencial.sh](../src/ocr_sequencial.sh).

The documentation is written in English and is intended to be suitable for a GitHub wiki or repository documentation page.

## Contents

- [Overview](./overview.md)
- [Architecture and runtime model](./architecture.md)
- [Execution flow and file processing](./processing-flow.md)
- [State, resume markers, and recovery](./state-and-recovery.md)

## What this script does

The script recursively scans a source directory, preserves the relative directory structure in a target directory, copies all non-PDF files, and performs OCR on PDF files using OCRmyPDF. It is designed to run inside a tmux session and exposes a progress pane plus a log pane while it is executing.

It has several important characteristics:

- It is intentionally sequential at the script level.
- It processes PDFs one at a time, even though OCRmyPDF can use multiple worker threads internally.
- It writes output to temporary files before publishing final files.
- It stores marker files in a hidden state directory for resumable processing.
- It continues processing other files after a failed item and exits with a non-zero status if any item failed.

## Primary entry point

- Script: [src/ocr_sequencial.sh](../src/ocr_sequencial.sh)
- Native binary: [bin/ocr_sequencial](../bin/ocr_sequencial) (if present in the build output)

## Script purpose in one sentence

The script provides a resumable, tmux-driven OCR pipeline for copying a directory tree and OCR-processing PDFs while keeping an auditable progress display and robust artifact publication.

## Recommended reading order

1. [Overview](./overview.md): explains the goals, assumptions, and runtime environment.
2. [Architecture and runtime model](./architecture.md): explains the main variables, functions, and tmux workspaces.
3. [Execution flow and file processing](./processing-flow.md): details the exact sequence of operations.
4. [State, resume markers, and recovery](./state-and-recovery.md): explains how the script detects previously completed work and how it recovers from partial failures.

## Quick reference

### Dependencies

The script requires:

- Bash
- tmux
- OCRmyPDF
- GNU/Linux command-line utilities: `find`, `realpath`, `sha256sum`, `cmp`, `mktemp`, `cp`, `mv`, `tail`, `nproc`

### Invocation

```bash
bash src/ocr_sequencial.sh "/path/to/source" "/path/to/target"
```

### Runtime expectations

- The script must run from inside a tmux session.
- The source and target directories must be different.
- The target directory cannot be inside the source directory.
- A hidden metadata directory is created under the target: `.ocr_sequencial_state`.

## Documentation conventions

This documentation is intentionally technical and implementation-oriented. It focuses on how the script actually behaves, including edge cases and operational safeguards, rather than only describing the desired workflow.

When there is a discrepancy between an older README statement and the actual implementation, the implementation in [src/ocr_sequencial.sh](../src/ocr_sequencial.sh) is treated as the authoritative source.

---

This documentation set is intended to complement the repository-level README and provide deeper operational detail for maintainers and advanced users.
