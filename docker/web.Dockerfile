# 开发阶段
FROM node:20-alpine AS development
WORKDIR /app
ENV TZ=Asia/Shanghai
ARG NPM_REGISTRY=https://registry.npmmirror.com

# 安装 pnpm
RUN npm install -g pnpm@latest

# 复制 package.json 和 pnpm-lock.yaml
COPY ./web/package*.json ./
COPY ./web/pnpm-lock.yaml* ./

# 安装依赖
RUN pnpm install --registry=${NPM_REGISTRY}

# 复制源代码
COPY ./web .

# 暴露端口
EXPOSE 5173

# 启动开发服务器的命令在 docker-compose 文件中定义

# 生产阶段
FROM node:20-alpine AS build-stage
WORKDIR /app
ARG VITE_LITE_MODE=false
ARG VITE_USE_RUNS_API=false
ARG NPM_REGISTRY=https://registry.npmmirror.com
ENV VITE_LITE_MODE=${VITE_LITE_MODE}
ENV VITE_USE_RUNS_API=${VITE_USE_RUNS_API}

# 安装 pnpm
RUN npm install -g pnpm@latest

# 复制依赖文件
COPY ./web/package*.json ./
COPY ./web/pnpm-lock.yaml* ./

# 安装依赖
RUN pnpm install --frozen-lockfile --registry=${NPM_REGISTRY}

# 复制源代码并构建
COPY ./web .
RUN pnpm run build

# 生产环境运行阶段
FROM nginx:alpine AS production
COPY --from=build-stage /app/dist /usr/share/nginx/html
COPY ./docker/nginx/nginx.conf /etc/nginx/nginx.conf
COPY ./docker/nginx/default.conf /etc/nginx/conf.d/default.conf
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
