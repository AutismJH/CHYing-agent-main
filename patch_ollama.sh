#!/bin/bash

# CHYing Agent Ollama 集成自动补丁脚本
# 功能：自动修改原项目文件，添加 Ollama 支持
# 使用：chmod +x patch_ollama.sh && ./patch_ollama.sh

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

echo "
╔════════════════════════════════════════════════════════════╗
║         CHYing Agent Ollama 集成补丁脚本                   ║
║         自动修改原项目，添加 Ollama 支持                   ║
╚════════════════════════════════════════════════════════════╝
"

# 检查是否在项目根目录
if [ ! -f "pyproject.toml" ] || [ ! -d "chying_agent" ]; then
    print_error "请在 CHYing-agent 项目根目录下运行此脚本"
    exit 1
fi

print_info "开始应用补丁..."

# 备份原文件
print_info "创建备份..."
mkdir -p .backup_$(date +%Y%m%d_%H%M%S)
BACKUP_DIR=".backup_$(date +%Y%m%d_%H%M%S)"

# ==================== 1. 创建 model_ollama.py ====================
print_info "[1/6] 创建 chying_agent/model_ollama.py..."

cat > chying_agent/model_ollama.py << 'EOF'
"""
Ollama 模型适配器
==================

提供本地 Ollama 模型的集成支持。
"""
import logging
from typing import Optional
from langchain_core.language_models import BaseChatModel
from chying_agent.common import log_system_event


def create_ollama_model(
    base_url: str = "http://192.168.10.117:11434",
    model: str = "deepseek-r1:32b",
    temperature: float = 0.5,
    num_ctx: int = 8192,
    timeout: int = 300,
    num_predict: int = 4096
) -> BaseChatModel:
    """创建 Ollama 模型实例"""
    try:
        from langchain_ollama import ChatOllama
    except ImportError as e:
        raise ImportError(
            "langchain-ollama 未安装。请运行: pip install langchain-ollama"
        ) from e
    
    log_system_event(
        "✅ 创建 Ollama 模型实例",
        {
            "base_url": base_url,
            "model": model,
            "temperature": temperature,
            "num_ctx": num_ctx,
            "timeout": timeout,
            "num_predict": num_predict
        }
    )
    
    try:
        model_instance = ChatOllama(
            base_url=base_url,
            model=model,
            temperature=temperature,
            num_ctx=num_ctx,
            timeout=timeout,
            num_predict=num_predict
        )
        
        _verify_ollama_connection(base_url, model)
        
        return model_instance
    
    except Exception as e:
        log_system_event(
            f"❌ Ollama 模型创建失败: {str(e)}",
            {"base_url": base_url, "model": model},
            level=logging.ERROR
        )
        raise ConnectionError(
            f"无法连接到 Ollama 服务器 ({base_url})。\n"
            f"请确保 Ollama 服务正在运行且模型已下载。"
        ) from e


def _verify_ollama_connection(base_url: str, model: str) -> None:
    """验证 Ollama 连接和模型可用性"""
    import requests
    
    try:
        response = requests.get(f"{base_url}/api/tags", timeout=5)
        response.raise_for_status()
        
        available_models = response.json().get("models", [])
        model_names = [m["name"] for m in available_models]
        
        if model not in model_names:
            log_system_event(
                f"⚠️ 警告：模型 '{model}' 未找到",
                {
                    "available_models": model_names[:5],
                    "suggestion": f"运行 'ollama pull {model}' 下载模型"
                },
                level=logging.WARNING
            )
        else:
            log_system_event(f"✅ Ollama 模型 '{model}' 验证成功")
    
    except requests.exceptions.RequestException as e:
        raise ConnectionError(
            f"无法连接到 Ollama 服务器 ({base_url}): {str(e)}"
        ) from e


def list_available_ollama_models(base_url: str = "http://192.168.10.117:11434") -> list:
    """列出可用的 Ollama 模型"""
    import requests
    
    try:
        response = requests.get(f"{base_url}/api/tags", timeout=5)
        response.raise_for_status()
        
        models = response.json().get("models", [])
        model_info = []
        
        for model in models:
            model_info.append({
                "name": model["name"],
                "size": f"{model['size'] / 1e9:.2f} GB",
                "quantization": model["details"].get("quantization_level", "unknown")
            })
        
        log_system_event(
            f"📋 Ollama 可用模型列表",
            {"count": len(model_info), "models": model_info}
        )
        
        return model_info
    
    except Exception as e:
        log_system_event(
            f"❌ 获取 Ollama 模型列表失败: {str(e)}",
            level=logging.ERROR
        )
        return []
EOF

print_success "model_ollama.py 创建完成"

# ==================== 2. 修改 config.py ====================
print_info "[2/6] 修改 chying_agent/config.py..."

# 备份原文件
cp chying_agent/config.py "$BACKUP_DIR/config.py.bak"

# 在 import 部分添加 Literal
sed -i '1i from typing import Literal' chying_agent/config.py

# 修改 AgentConfig 类（这里简化处理，实际需要更复杂的 sed 操作）
# 建议：直接提供完整的 config.py 替换文件

print_warning "config.py 需要手动修改（sed 脚本复杂度过高）"
print_info "请参考文档手动修改，或使用提供的完整文件替换"

# ==================== 3. 修改 pyproject.toml ====================
print_info "[3/6] 修改 pyproject.toml..."

cp pyproject.toml "$BACKUP_DIR/pyproject.toml.bak"

# 在 dependencies 中添加 langchain-ollama
sed -i '/dependencies = \[/a \    "langchain-ollama>=1.0.0",' pyproject.toml

print_success "pyproject.toml 修改完成"

# ==================== 4. 修改 .env.example ====================
print_info "[4/6] 修改 .env.example..."

cp .env.example "$BACKUP_DIR/.env.example.bak"

# 在文件开头添加 LLM_BACKEND 配置
sed -i '1i # ============================================\n# LLM 后端配置\n# ============================================\nLLM_BACKEND=api\n' .env.example

# 在 LLM 配置部分后添加 Ollama 配置
cat >> .env.example << 'EOF'

# ============================================
# Ollama 配置（仅在 LLM_BACKEND=ollama 时需要）
# ============================================
OLLAMA_BASE_URL=http://192.168.10.117:11434
OLLAMA_MAIN_MODEL=deepseek-r1:32b
OLLAMA_ADVISOR_MODEL=qwen3:latest
OLLAMA_TEMPERATURE=0.5
OLLAMA_NUM_CTX=8192
OLLAMA_NUM_PREDICT=4096
OLLAMA_TIMEOUT=300
EOF

print_success ".env.example 修改完成"

# ==================== 5. 创建文档 ====================
print_info "[5/6] 创建 QUICKSTART_OLLAMA.md..."

cat > QUICKSTART_OLLAMA.md << 'EOF'
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
EOF

print_success "QUICKSTART_OLLAMA.md 创建完成"

# ==================== 6. 提示手动修改项 ====================
print_info "[6/6] 生成手动修改清单..."

cat > MANUAL_MODIFICATIONS.md << 'EOF'
# 需要手动修改的文件

由于这些文件的修改较为复杂，无法通过简单的 sed 脚本完成，请手动修改：

## 1. chying_agent/config.py

### 修改 1：添加 Ollama 参数到 __init__

在 `AgentConfig` 类的 `__init__` 方法中，添加：

```python
def __init__(self,
             # ⭐ 新增
             llm_backend: Literal["api", "ollama"] = "api",
             
             # 原有的 API 配置（改为 Optional）
             llm_api_key: Optional[str] = None,
             llm_base_url: Optional[str] = None,
             
             # ⭐ 新增 Ollama 配置
             ollama_base_url: str = "http://192.168.10.117:11434",
             ollama_main_model: str = "deepseek-r1:32b",
             ollama_advisor_model: str = "qwen3:latest",
             ollama_temperature: float = 0.5,
             ollama_num_ctx: int = 8192,
             ollama_num_predict: int = 4096,
             ollama_timeout: int = 300,
             
             # ... 原有配置):
    
    self.llm_backend = llm_backend
    self.ollama_base_url = ollama_base_url
    # ... 保存其他 Ollama 配置
```

### 修改 2：更新 load_agent_config()

```python
def load_agent_config() -> AgentConfig:
    load_dotenv()
    
    # ⭐ 新增
    llm_backend = os.getenv("LLM_BACKEND", "api").lower()
    
    # ⭐ 新增 Ollama 配置读取
    ollama_base_url = os.getenv("OLLAMA_BASE_URL", "http://192.168.10.117:11434")
    ollama_main_model = os.getenv("OLLAMA_MAIN_MODEL", "deepseek-r1:32b")
    # ... 读取其他 Ollama 配置
    
    # ⭐ 修改：API 配置改为可选
    if llm_backend == "api":
        llm_api_key = os.getenv("DEEPSEEK_API_KEY")
        if not llm_api_key:
            raise ValueError("API 模式下必须设置 DEEPSEEK_API_KEY")
    else:
        llm_api_key = None
    
    return AgentConfig(
        llm_backend=llm_backend,
        ollama_base_url=ollama_base_url,
        ollama_main_model=ollama_main_model,
        # ... 其他参数
    )
```

## 2. chying_agent/model.py

### 修改：create_model() 函数

```python
def create_model(config: AgentConfig, ...) -> BaseChatModel:
    # ⭐ 新增：根据 backend 选择
    if config.llm_backend == "ollama":
        from chying_agent.model_ollama import create_ollama_model
        return create_ollama_model(
            base_url=config.ollama_base_url,
            model=config.ollama_main_model,
            # ... 其他参数
        )
    else:
        # 原有的 API 模式代码
        from langchain_deepseek import ChatDeepSeek
        # ...
```

### 新增：create_advisor_model() 函数

```python
def create_advisor_model(config: AgentConfig) -> BaseChatModel:
    """创建顾问模型"""
    if config.llm_backend == "ollama":
        from chying_agent.model_ollama import create_ollama_model
        return create_ollama_model(
            base_url=config.ollama_base_url,
            model=config.ollama_advisor_model,  # 使用顾问模型
            # ...
        )
    else:
        # 原有的 MiniMax 代码
        from langchain_openai import ChatOpenAI
        # ...
```

## 3. chying_agent/retry_strategy.py

### 修改：__init__() 方法

```python
def __init__(self, config):
    self.config = config
    
    # ⭐ 修改：使用新的 create_advisor_model
    self.main_llm = create_model(config=config)
    self.advisor_llm = create_advisor_model(config=config)  # 新增
```

## 修改完成后的验证

```bash
# 测试导入
python3 -c "from chying_agent.model_ollama import create_ollama_model; print('OK')"

# 测试配置
python3 -c "from chying_agent.config import load_agent_config; print(load_agent_config().llm_backend)"
```

EOF

print_success "手动修改清单已生成：MANUAL_MODIFICATIONS.md"

# ==================== 完成 ====================
echo ""
print_success "补丁应用完成！"
echo ""
print_warning "⚠️ 重要提示："
echo "  1. 部分文件需要手动修改（见 MANUAL_MODIFICATIONS.md）"
echo "  2. 原文件备份在：$BACKUP_DIR/"
echo "  3. 修改完成后运行：uv sync"
echo ""
print_info "下一步："
echo "  1. 阅读 MANUAL_MODIFICATIONS.md 并完成手动修改"
echo "  2. 复制 .env.example 到 .env 并配置"
echo "  3. 运行 uv sync 安装依赖"
echo "  4. 运行 uv run main.py -t http://target.com 测试"
echo ""
