# 使用轻量级Python基础镜像
FROM python:3.12-slim
COPY --from=ghcr.io/astral-sh/uv:0.7.2 /uv /uvx /bin/
COPY --from=node:20-slim /usr/local/bin /usr/local/bin
COPY --from=node:20-slim /usr/local/lib/node_modules /usr/local/lib/node_modules
COPY --from=node:20-slim /usr/local/include /usr/local/include
COPY --from=node:20-slim /usr/local/share /usr/local/share

# 设置工作目录
WORKDIR /app
ARG UV_DEFAULT_INDEX=https://pypi.org/simple

# 环境变量设置
ENV TZ=Asia/Shanghai \
    UV_PROJECT_ENVIRONMENT="/usr/local" \
    UV_COMPILE_BYTECODE=1 \
    UV_HTTP_TIMEOUT=120 \
    DEBIAN_FRONTEND=noninteractive

# 设置 npm 镜像源，为 MCP 和 Skills 安装依赖
RUN npm config set registry https://registry.npmmirror.com --global \
    && npm cache clean --force

# 设置代理和时区，更换镜像源，安装系统依赖 - 合并为一个RUN减少层数
RUN set -ex \
    # (A) 设置时区
    && ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone \
    # (B) 替换清华源 (针对 Debian Bookworm 的新版格式)
    && sed -i 's|deb.debian.org|mirrors.tuna.tsinghua.edu.cn|g' /etc/apt/sources.list.d/debian.sources \
    && sed -i 's|security.debian.org/debian-security|mirrors.tuna.tsinghua.edu.cn/debian-security|g' /etc/apt/sources.list.d/debian.sources \
    # (C) 安装必要的系统库
    && apt-get update \
    && apt-get install -y --no-install-recommends --fix-missing \
        curl \
        ffmpeg \
        git \
        libpq5 \
        libsm6 \
        libxext6 \
    # (D) 清理垃圾，减小体积
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# 复制项目配置文件
COPY ../backend/pyproject.toml /app/pyproject.toml
COPY ../backend/.python-version /app/.python-version
COPY ../backend/uv.lock /app/uv.lock
COPY ../README.md /app/README.md
COPY ../backend/package /app/package

# 先在容器内基于指定索引重建 lock，再执行安装，避免宿主机提交的 uv.lock
# 把第三方包下载地址固定到旧镜像源。
RUN --mount=type=cache,target=/root/.cache/uv \
    uv lock --default-index "${UV_DEFAULT_INDEX}" --refresh \
    && uv sync --default-index "${UV_DEFAULT_INDEX}" --group test --no-dev --frozen

# 激活虚拟环境并添加到PATH
ENV PATH="/app/.venv/bin:$PATH"

# 复制代码到容器中
COPY ../backend/server /app/server
