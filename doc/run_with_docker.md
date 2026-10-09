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

The script requires a tmux session. In the container, start tmux and run the script from the directory where it is installed:

```bash
tmux new-session
bash /path/to/ocr_sequencial.sh
```

The script scans `/source`, OCRs PDF files, and copies other files to `/destination`. It creates progress and log panes in tmux. Completed OCR files and state markers are written to the output directory; logs are kept under `/tmp` in the container and are removed when the container exits.
