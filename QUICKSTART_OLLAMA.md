# CHYing Agent - Ollama 快速开始

## 配置步骤

1. 复制配置文件
```bash
cp .env.example .env
```

2. 编辑 .env，设置 Ollama 模式
```bash
LLM_BACKEND=ollama
OLLAMA_BASE_URL=http://192.168.10.117:11434
OLLAMA_MAIN_MODEL=deepseek-r1:32b
OLLAMA_ADVISOR_MODEL=qwen3:latest
```

3. 安装依赖
```bash
uv sync
```

4. 运行
```bash
uv run main.py -t http://target.com
```

详见完整文档。
