#!/bin/bash
set -e
DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$DIR/db_init_build"
ZIP="$DIR/db_init_lambda.zip"

echo "Building DB Init Lambda package..."
rm -rf "$BUILD_DIR" "$ZIP"
mkdir -p "$BUILD_DIR"

cp "$DIR/db_init_lambda/index.py" "$BUILD_DIR/"

docker run --rm \
  -v "$BUILD_DIR":/var/task \
  -v "$DIR/db_init_lambda":/src \
  public.ecr.aws/lambda/python:3.11 \
  bash -c "pip install psycopg2-binary boto3 -t /var/task/ --quiet && cp /src/index.py /var/task/"

cd "$BUILD_DIR"
zip -r "$ZIP" . -q

echo "Lambda zip created: $ZIP"
echo "Size: $(du -sh "$ZIP" | cut -f1)"
