#!/bin/bash
set -e
DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$DIR/db_init_build"
ZIP="$DIR/db_init_lambda.zip"

echo "Building DB Init Lambda package..."

# حذف المجلد القديم حتى لو كان owned by root
if [ -d "$BUILD_DIR" ]; then
    docker run --rm -v "$DIR":/workspace public.ecr.aws/lambda/python:3.12 \
        bash -c "rm -rf /workspace/db_init_build"
fi
mkdir -p "$BUILD_DIR"

cp "$DIR/db_init_lambda/index.py" "$BUILD_DIR/"

# بناء الـ packages داخل Lambda python3.12 environment
docker run --rm \
    -v "$BUILD_DIR":/var/task \
    public.ecr.aws/lambda/python:3.12 \
    pip install psycopg2-binary boto3 -t /var/task/ --quiet

# تغيير الـ ownership لـ jenkins
docker run --rm -v "$DIR":/workspace public.ecr.aws/lambda/python:3.12 \
    bash -c "chown -R $(id -u):$(id -g) /workspace/db_init_build" 2>/dev/null || true

cd "$BUILD_DIR"
zip -r "$ZIP" . -q

echo "Lambda zip created: $ZIP"
echo "Size: $(du -sh "$ZIP" | cut -f1)"
