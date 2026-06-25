FROM node:20-bookworm

RUN apt-get update && apt-get install -y \
    bash \
    curl \
    git \
    ca-certificates \
    python3 \
    python3-venv \
    && rm -rf /var/lib/apt/lists/*

# Install uv globally as root
RUN curl -LsSf https://astral.sh/uv/install.sh | env UV_INSTALL_DIR=/usr/local/bin sh

# 1. Create the dedicated non-root user and pre-make the required directories
RUN useradd -m -s /bin/bash claude \
    && mkdir -p /home/claude/.claude \
    && mkdir -p /home/claude/.local/bin \
    && chown -R claude:claude /home/claude

# 2. Switch to the non-root user BEFORE installing Claude
USER claude
WORKDIR /workspace

# 3. Cache buster to force updates when needed
ARG CLAUDE_UPDATE_DATE=2026-06-25-v2

# 4. Install Claude directly into the claude user's home directory
RUN curl -fsSL https://claude.ai/install.sh | bash

# 5. Add the local bin folder to the environment PATH so the system can find it
ENV PATH="/home/claude/.local/bin:${PATH}"

CMD ["/bin/bash"]