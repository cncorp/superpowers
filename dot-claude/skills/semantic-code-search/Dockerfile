FROM python:3.11-slim

WORKDIR /workspace

# Install system dependencies for PostgreSQL
RUN apt-get update && apt-get install -y \
    postgresql-client \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements and install Python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy source code
COPY src/ ./src/

# Make CLI executable and create symlink
RUN chmod +x src/cli.py && ln -sf /workspace/src/cli.py /usr/local/bin/code-search

CMD ["tail", "-f", "/dev/null"]