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

