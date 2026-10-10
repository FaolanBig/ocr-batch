# Run OCR in Docker

## Build the image

From the `docker` directory (the build script uses the current directory as its build context):

```bash
cd docker
sudo bash build_dockerfile.sh
```

This builds the image `ocr_batch_sequencial:1.1.1`.

## Start a container

Mount the input directory read-only at `/source` and an output directory at `/destination`:

```bash
docker run --rm -it \
	-v /path/to/input:/source:ro \
	-v /path/to/output:/destination \
	-e OCR_JOBS=4 \
	ocr_batch_sequencial:1.1.1
```

Replace the example host paths and adjust `OCR_JOBS` to set the number of OCR threads. If omitted, the script uses 75% of the available CPUs.

## Run the script

The container starts the script automatically (no tmux needed). It scans `/source`, OCRs PDF files, and copies other files to `/destination`. Script messages are shown in the terminal and also written to a log file; the ocrmypdf output and progress are only written to the log file. Logs are stored in `/destination/.ocr_sequencial_state/logs` (override with `-e LOG_DIR=...`). Completed OCR files and state markers are written to the output directory.
