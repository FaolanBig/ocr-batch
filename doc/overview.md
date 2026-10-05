# Script overview

## Scope and purpose

The script in [scr/ocr_sequencial.sh](../scr/ocr_sequencial.sh) is a batch OCR workflow for directory trees. It was designed to process a large source tree without requiring the user to manually watch each file and without losing safety guarantees when writing output.

Its responsibilities are:

- validate input paths and required tools
- ensure the script is run from within tmux
- scan the source tree for files
- copy non-PDF files into the target directory while preserving structure
- process PDF files one at a time with OCRmyPDF
- write output to a temporary file before publishing it
- record a state marker so already-processed PDFs can be skipped safely on subsequent runs
- provide a live progress display and OCR logs in tmux panes
- exit with clear success or failure conditions

The script is not a distributed OCR scheduler; it is a single-process, sequential pipeline with robust output publication and resume behavior.

## Execution model

The script starts by validating the arguments, required commands, and directory relationships. Then it creates a target state directory and opens two tmux panes:

1. a progress pane that updates every second
2. a log pane that follows the OCR log file in real time

After the UI is created, the script enumerates every regular file under the source tree. It splits the results into two groups:

- PDF files, identified by a case-insensitive `.pdf` suffix
- all other files

Then it performs two main passes:

- first pass: copy non-PDF files
- second pass: OCR PDF files

This separation ensures that documents, images, and arbitrary files are preserved first, while OCR work is concentrated only on PDF inputs.

## Operational assumptions

The workflow assumes the following:

- the user wants a mirrored target directory that keeps the same relative layout as the source tree
- the source tree is treated as read-only while processing
- destination files may be replaced when their source is newer or unverified
- the target can be a fresh directory or an existing directory that already contains some prior output
- failures should not abort the entire batch; the script records them and continues wherever possible

## Safety model

One of the central design goals is to avoid publishing partially written or corrupted files. The script uses temporary files for both file copies and OCR outputs:

- copy: source file is copied to `${out}.copy-${RUN_ID}.tmp`, then moved to the final output path
- OCR: PDF is OCR-processed to `${out}.ocr-${RUN_ID}.tmp.pdf`, then moved into place only after success

This ensures that a process that fails midway does not leave a final destination file in a partially written state.

## Readiness and idempotence

The script is designed to be repeatable. It does not blindly re-run OCR for every PDF. Instead, it calculates a deterministic marker for each relative file path and stores a source signature based on:

- the absolute relative path within the source tree
- the SHA-256 checksum of the source PDF

If the output file exists and the saved marker still matches the current source signature, the PDF is skipped. This gives the script an important resume-like behavior without requiring a full state database.

## State directory

The target directory gains a hidden metadata directory:

```text
<target_dir>/.ocr_sequencial_state
```

Inside it, the script stores one marker per processed PDF. The marker file name is derived from a SHA-256 hash of the relative path, which allows the script to avoid storing large path names while still providing a stable lookup key.

## Why it runs under tmux

The script intentionally refuses to run unless `TMUX` is set, meaning it must be started from an active tmux session. This is not arbitrary; it allows the script to create additional panes for:

- showing progress and counters
- following the OCR log in real time

This makes the batch process usable as a background-like operation while still remaining observable from the same terminal session.

## Important implementation note

The script contains a set of commented-out environment-driven thread settings:

```bash
#CPU_THREADS="${OCR_JOBS:-2}"
#export CPU_THREADS="${OCR_JOBS:-2}"
#export CPU_THREADS="${OCR_JOBS:-CPU_THREADS=$(($(nproc --all) / 2))}"
```

The active code instead does:

```bash
export CPU_THREADS="$(($(nproc --all) / 4 * 3))"
```

That means the script currently uses roughly 75% of available logical CPUs when invoking OCRmyPDF with `--jobs`. The repository README may mention a different default behavior, but the actual file as implemented is authoritative.

## Success and failure semantics

On exit, the script reports one of two outcomes:

- success: no failed PDFs and no failed other-file copies
- failure: at least one PDF or non-PDF failed during the run

A failed item does not stop the whole run; the script continues processing all remaining files before printing the final summary and exiting with status 1 if any errors were recorded.

## Summary

This script is best understood as a resilient, resumable OCR batch job with a user-facing progress dashboard. It is intentionally conservative about publishing output, uses file markers to avoid unnecessary reprocessing, and is structured to maximize visibility and debugging during a long-running job.
