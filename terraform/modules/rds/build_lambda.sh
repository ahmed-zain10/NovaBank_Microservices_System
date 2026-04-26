#!/bin/bash
# Run this from the modules/rds directory before terraform apply
# It packages the Lambda function with psycopg2 dependencies

set -e
DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$DIR/db_init_build"
ZIP="$DIR/db_init_lambda.zip"

echo "Building DB Init Lambda package..."
rm -rf "$BUILD_DIR" "$ZIP"
mkdir -p "$BUILD_DIR"

# Install psycopg2-binary compiled for Lambda (Amazon Linux 2023)
pip install psycopg2-binary boto3 --target "$BUILD_DIR" --quiet \
  --platform manylinux2014_x86_64 --only-binary=:all:

cp "$DIR/db_init_lambda/index.py" "$BUILD_DIR/"

cd "$BUILD_DIR"
zip -r "$ZIP" . -q

echo "Lambda zip created: $ZIP"
echo "Size: $(du -sh "$ZIP" | cut -f1)"
