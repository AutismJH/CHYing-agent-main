import os
from typing import Optional, Literal
from dotenv import load_dotenv


class AgentConfig:
    def __init__(self,
                 # LLM 后端类型
                 llm_backend: Literal["api", "ollama"] = "api",
                 # API 配置
                 llm_api_key: Optional[str] = None,
                 llm_base_url: Optional[str] = None,
                 llm_model_name: str = "deepseek-v3.1-terminus",
                 # Ollama 配置
                 ollama_base_url: str = "http://192.168.10.117:11434/",
                 ollama_main_model: str = "deepseek-r1:32b",
                 ollama_advisor_model: str = "qwen3:latest",
                 ollama_temperature: float = 0.5,
                 ollama_num_ctx: int = 8192,
                 ollama_num_predict: int = 4096,
                 ollama_timeout: int = 300,
                 # 环境模式配置
                 env_mode: str = "competition",
                 # Docker 配置
                 docker_container_name: Optional[str] = None,
                 # Microsandbox 配置
                 sandbox_enabled: bool = False,
                 sandbox_name: str = "CHYing-sandbox"):
        
        self.llm_backend = llm_backend
        
        # API 配置
        self.llm_api_key = llm_api_key
        self.llm_base_url = llm_base_url
        self.llm_model_name = llm_model_name
        
        # Ollama 配置
        self.ollama_base_url = ollama_base_url
        self.ollama_main_model = ollama_main_model
        self.ollama_advisor_model = ollama_advisor_model
        self.ollama_temperature = ollama_temperature
        self.ollama_num_ctx = ollama_num_ctx
        self.ollama_num_predict = ollama_num_predict
        self.ollama_timeout = ollama_timeout
        
        # 环境模式
        self.env_mode = env_mode
        
        # Docker 配置
        self.docker_container_name = docker_container_name
        
        # Microsandbox 配置
        self.sandbox_enabled = sandbox_enabled
        self.sandbox_name = sandbox_name


def load_agent_config() -> AgentConfig:
    load_dotenv()  # 确保.env文件被加载
    
    # 读取 LLM 后端类型
    llm_backend = os.getenv("LLM_BACKEND", "api").lower()
    
    if llm_backend not in ["api", "ollama"]:
        raise ValueError(f"配置错误: LLM_BACKEND 必须是 'api' 或 'ollama'，当前值: {llm_backend}")
    
    # API 配置
    llm_api_key = None
    llm_base_url = None
    llm_model_name = "deepseek-v3.1-terminus"
    
    if llm_backend == "api":
        llm_api_key = os.getenv("DEEPSEEK_API_KEY") or os.getenv("OPENAI_API_KEY")
        if not llm_api_key:
            raise ValueError(
                "配置错误: API 模式下必须设置 DEEPSEEK_API_KEY 或 OPENAI_API_KEY"
            )
        llm_base_url = os.getenv("DEEPSEEK_BASE_URL", "https://api.lkeap.cloud.tencent.com/v1")
        llm_model_name = os.getenv("LLM_MODEL_NAME", "deepseek-v3.1-terminus")
    
    # Ollama 配置
    ollama_base_url = os.getenv("OLLAMA_BASE_URL", "http://192.168.10.117:11434")
    ollama_main_model = os.getenv("OLLAMA_MAIN_MODEL", "deepseek-r1:32b")
    ollama_advisor_model = os.getenv("OLLAMA_ADVISOR_MODEL", "qwen3:latest")
    ollama_temperature = float(os.getenv("OLLAMA_TEMPERATURE", "0.5"))
    ollama_num_ctx = int(os.getenv("OLLAMA_NUM_CTX", "8192"))
    ollama_num_predict = int(os.getenv("OLLAMA_NUM_PREDICT", "4096"))
    ollama_timeout = int(os.getenv("OLLAMA_TIMEOUT", "300"))
    
    # 环境模式
    env_mode = os.getenv("ENV_MODE", "competition").lower()
    if env_mode not in ["competition"]:
        raise ValueError(f"配置错误: ENV_MODE 必须是 'competition'，当前值: {env_mode}")
    
    # Docker 配置
    docker_container_name = os.getenv("DOCKER_CONTAINER_NAME")
    
    # 沙箱配置
    sandbox_enabled = os.getenv("SANDBOX_ENABLED", "false").lower() == "true"
    sandbox_name = os.getenv("SANDBOX_NAME", "CHYing-sandbox")
    
    return AgentConfig(
        llm_backend=llm_backend,
        llm_api_key=llm_api_key,
        llm_base_url=llm_base_url,
        llm_model_name=llm_model_name,
        ollama_base_url=ollama_base_url,
        ollama_main_model=ollama_main_model,
        ollama_advisor_model=ollama_advisor_model,
        ollama_temperature=ollama_temperature,
        ollama_num_ctx=ollama_num_ctx,
        ollama_num_predict=ollama_num_predict,
        ollama_timeout=ollama_timeout,
        env_mode=env_mode,
        docker_container_name=docker_container_name,
        sandbox_enabled=sandbox_enabled,
        sandbox_name=sandbox_name
    )
