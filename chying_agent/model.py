import os
from langchain_core.language_models import BaseChatModel
from chying_agent.common import log_system_event
from chying_agent.config import AgentConfig


def create_model(
    config: AgentConfig,
    temperature: float = None,
    max_tokens: int = None,
    timeout: int = None,
    max_retries: int = 20
) -> BaseChatModel:
    """
    创建模型实例（支持 API 和 Ollama 两种后端）
    
    Args:
        config: AgentConfig实例，包含LLM配置
        temperature: 温度参数（None 时使用配置默认值）
        max_tokens: 最大token数（None 时使用配置默认值）
        timeout: 超时时间（None 时使用配置默认值）
        max_retries: 重试次数
        
    Returns:
        BaseChatModel: 模型实例
    """
    if config.llm_backend == "ollama":
        return _create_ollama_model(config, temperature, max_tokens, timeout)
    else:
        return _create_api_model(config, temperature, max_tokens, timeout, max_retries)


def _create_ollama_model(
    config: AgentConfig,
    temperature: float = None,
    max_tokens: int = None,
    timeout: int = None
) -> BaseChatModel:
    """创建 Ollama 模型实例"""
    from chying_agent.model_ollama import create_ollama_model
    
    # 使用配置中的默认值（如果未指定）
    temperature = temperature or config.ollama_temperature
    num_predict = max_tokens or config.ollama_num_predict
    timeout = timeout or config.ollama_timeout
    
    model = create_ollama_model(
        base_url=config.ollama_base_url,
        model=config.ollama_main_model,
        temperature=temperature,
        num_ctx=config.ollama_num_ctx,
        timeout=timeout,
        num_predict=num_predict
    )
    
    log_system_event(
        "✅ 创建 Ollama 主攻手模型",
        {
            "backend": "ollama",
            "model": config.ollama_main_model,
            "temperature": temperature,
            "num_ctx": config.ollama_num_ctx,
            "num_predict": num_predict
        }
    )
    
    return model


def _create_api_model(
    config: AgentConfig,
    temperature: float = None,
    max_tokens: int = None,
    timeout: int = None,
    max_retries: int = 20
) -> BaseChatModel:
    """创建 API 模型实例（DeepSeek）"""
    from langchain_deepseek import ChatDeepSeek
    
    # 使用默认值（如果未指定）
    temperature = temperature or 0.5
    max_tokens = max_tokens or 12800
    timeout = timeout or 600
    
    model = ChatDeepSeek(
        api_base=config.llm_base_url,
        api_key=config.llm_api_key,
        model=config.llm_model_name,
        temperature=temperature,
        max_tokens=max_tokens,
        timeout=timeout,
        max_retries=max_retries,
        streaming=False,
        extra_body={
            "thinking": {
                "type": "enabled",
                "enable_search": True,
            }
        }
    )
    
    log_system_event(
        "✅ 创建 DeepSeek API 模型",
        {
            "backend": "api",
            "model": config.llm_model_name,
            "temperature": temperature,
            "max_tokens": max_tokens,
            "timeout": timeout,
            "max_retries": max_retries
        }
    )
    
    return model


def create_advisor_model(config: AgentConfig) -> BaseChatModel:
    """
    创建顾问模型实例（支持 Ollama 和 API）
    
    Args:
        config: AgentConfig实例
        
    Returns:
        顾问模型实例
    """
    if config.llm_backend == "ollama":
        from chying_agent.model_ollama import create_ollama_model
        
        model = create_ollama_model(
            base_url=config.ollama_base_url,
            model=config.ollama_advisor_model,  # 使用单独的顾问模型
            temperature=0.7,
            num_ctx=config.ollama_num_ctx,
            timeout=config.ollama_timeout,
            num_predict=config.ollama_num_predict
        )
        
        log_system_event(
            "✅ 创建 Ollama 顾问模型",
            {
                "backend": "ollama",
                "model": config.ollama_advisor_model,
                "temperature": 0.7
            }
        )
        
        return model
    else:
        # API 模式：使用 MiniMax 或其他模型
        from langchain_openai import ChatOpenAI
        
        model = ChatOpenAI(
            base_url=os.getenv("SILICONFLOW_BASE_URL", "https://api.siliconflow.cn/v1"),
            api_key=os.getenv("SILICONFLOW_API_KEY"),
            model=os.getenv("SILICONFLOW_MODEL", "MiniMaxAI/MiniMax-M2"),
            temperature=0.7,
            max_tokens=8192,
            timeout=600,
            max_retries=10
        )
        
        log_system_event(
            "✅ 创建 MiniMax API 顾问模型",
            {
                "backend": "api",
                "model": os.getenv("SILICONFLOW_MODEL", "MiniMaxAI/MiniMax-M2")
            }
        )
        
        return model
