FROM node:20.19.1-bookworm AS front
WORKDIR /app
RUN npm install -g pnpm@10.10.0
COPY front/package.json .
COPY front/pnpm-lock.yaml .
COPY front/pnpm-workspace.yaml .
RUN pnpm install
COPY front/. .
RUN pnpm run generate

FROM golang:1.23.3-alpine AS backend
ARG VERSION
ARG COMMIT_ID
WORKDIR /app
RUN apk add --no-cache build-base tzdata
COPY backend/go.mod .
COPY backend/go.sum .
RUN go mod download
COPY backend/. .
# 适配 Zeabur 的输出路径
COPY --from=front /app/.zeabur/output/static /app/public

RUN go build -tags prod -ldflags="-s -w -X main.version=${VERSION} -X main.commitId=${COMMIT_ID}" -o /app/moments

# ... 前面构建步骤保持不变 ...

FROM alpine
# 建议工作目录设为 /app
WORKDIR /app
RUN apk update --no-cache && apk add --no-cache ca-certificates tzdata

# 1. 拷贝后端二进制文件
COPY --from=backend /app/moments /app/moments
# 2. 必须把前端静态资源也拷贝过来！否则 API 无法正常映射
COPY --from=front /app/.zeabur/output/static /app/public

# 确保数据目录存在（用于挂载）
RUN mkdir -p /app/data

ENV PORT=3000
ENV TZ=Asia/Shanghai

RUN chmod +x /app/moments
EXPOSE 3000

# 启动时明确指定在 /app 下运行
CMD ["/app/moments"]
