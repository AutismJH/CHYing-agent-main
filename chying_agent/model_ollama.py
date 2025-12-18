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
