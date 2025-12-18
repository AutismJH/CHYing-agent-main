#!/bin/bash

# CHYing Agent 一键部署脚本（修复版）
# 修复：支持 externally-managed-environment
# 修复：自动创建虚拟环境

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
║           CHYing Agent 一键部署脚本 v1.5.1                 ║
║           支持 API 和 Ollama 双后端                        ║
║           修复：自动创建虚拟环境                            ║
╚════════════════════════════════════════════════════════════╝
"

# ==================== 1. 环境检查 ====================
print_info "开始环境检查..."

# 检查 Python
if ! command -v python3 &> /dev/null; then
    print_error "Python 3 未安装，请先安装 Python 3.11+"
    exit 1
fi

PYTHON_VERSION=$(python3 --version | awk '{print $2}')
print_success "Python 版本: $PYTHON_VERSION"

# 检查 uv（推荐）
if ! command -v uv &> /dev/null; then
    print_warning "uv 未安装，将使用虚拟环境 + pip"
    print_info "推荐安装 uv: curl -LsSf https://astral.sh/uv/install.sh | sh"
    USE_UV=false
else
    print_success "uv 已安装"
    USE_UV=true
fi

# 检查 Docker
if ! command -v docker &> /dev/null; then
    print_error "Docker 未安装，请先安装 Docker"
    exit 1
fi

if ! docker ps &> /dev/null; then
    print_error "Docker 未运行或无权限，请检查 Docker 状态"
    exit 1
fi

print_success "Docker 运行正常"

# ==================== 2. 配置 .env 文件 ====================
print_info "配置 .env 文件..."

if [ -f .env ]; then
    print_warning ".env 文件已存在"
    read -p "是否重新配置？(y/N): " RECONFIGURE
    RECONFIGURE=${RECONFIGURE:-N}
else
    RECONFIGURE="y"
fi

if [[ "$RECONFIGURE" =~ ^[Yy]$ ]]; then
    echo ""
    echo "请选择 LLM 后端："
    echo "  1) API 模式（使用 DeepSeek、MiniMax 等在线 API）"
    echo "  2) Ollama 模式（使用本地 Ollama 模型）"
    read -p "请选择 (1/2): " BACKEND_CHOICE
    
    case $BACKEND_CHOICE in
        1)
            LLM_BACKEND="api"
            print_info "已选择 API 模式"
            read -p "请输入 DeepSeek API Key: " DEEPSEEK_API_KEY
            read -p "请输入 DeepSeek Base URL [https://api.lkeap.cloud.tencent.com/v1]: " DEEPSEEK_BASE_URL
            DEEPSEEK_BASE_URL=${DEEPSEEK_BASE_URL:-https://api.lkeap.cloud.tencent.com/v1}
            ;;
        2)
            LLM_BACKEND="ollama"
            print_info "已选择 Ollama 模式"
            read -p "请输入 Ollama 服务器地址 [http://192.168.10.117:11434]: " OLLAMA_BASE_URL
            OLLAMA_BASE_URL=${OLLAMA_BASE_URL:-http://192.168.10.117:11434}
            
            print_info "可用模型："
            echo "  - deepseek-r1:32b（推荐，主攻手）"
            echo "  - deepseek-r1:14b（轻量级）"
            echo "  - qwen3:latest（推荐，顾问）"
            
            read -p "主攻手模型 [deepseek-r1:32b]: " OLLAMA_MAIN_MODEL
            OLLAMA_MAIN_MODEL=${OLLAMA_MAIN_MODEL:-deepseek-r1:32b}
            
            read -p "顾问模型 [qwen3:latest]: " OLLAMA_ADVISOR_MODEL
            OLLAMA_ADVISOR_MODEL=${OLLAMA_ADVISOR_MODEL:-qwen3:latest}
            ;;
        *)
            print_error "无效选择，默认使用 API 模式"
            LLM_BACKEND="api"
            ;;
    esac
    
    read -p "Docker 容器名称 [kali-pentest]: " DOCKER_CONTAINER_NAME
    DOCKER_CONTAINER_NAME=${DOCKER_CONTAINER_NAME:-kali-pentest}
    
    print_info "生成 .env 文件..."
    cp .env.example .env
    
    # 更新配置
    sed -i "s|^LLM_BACKEND=.*|LLM_BACKEND=$LLM_BACKEND|" .env
    
    if [ "$LLM_BACKEND" = "api" ]; then
        sed -i "s|^DEEPSEEK_API_KEY=.*|DEEPSEEK_API_KEY=\"$DEEPSEEK_API_KEY\"|" .env
        sed -i "s|^DEEPSEEK_BASE_URL=.*|DEEPSEEK_BASE_URL=\"$DEEPSEEK_BASE_URL\"|" .env
    else
        sed -i "s|^OLLAMA_BASE_URL=.*|OLLAMA_BASE_URL=$OLLAMA_BASE_URL|" .env
        sed -i "s|^OLLAMA_MAIN_MODEL=.*|OLLAMA_MAIN_MODEL=$OLLAMA_MAIN_MODEL|" .env
        sed -i "s|^OLLAMA_ADVISOR_MODEL=.*|OLLAMA_ADVISOR_MODEL=$OLLAMA_ADVISOR_MODEL|" .env
    fi
    
    sed -i "s|^DOCKER_CONTAINER_NAME=.*|DOCKER_CONTAINER_NAME=$DOCKER_CONTAINER_NAME|" .env
    
    print_success ".env 文件配置完成"
else
    print_info "使用现有 .env 文件"
fi

# ==================== 3. 安装依赖 ====================
print_info "安装 Python 依赖..."

if [ "$USE_UV" = true ]; then
    # 使用 uv（推荐）
    print_info "使用 uv 安装依赖..."
    uv sync
    print_success "依赖安装完成（uv）"
else
    # 使用虚拟环境 + pip
    VENV_DIR=".venv"
    
    if [ ! -d "$VENV_DIR" ]; then
        print_info "创建虚拟环境: $VENV_DIR"
        python3 -m venv "$VENV_DIR"
        print_success "虚拟环境创建完成"
    else
        print_info "虚拟环境已存在: $VENV_DIR"
    fi
    
    print_info "激活虚拟环境并安装依赖..."
    source "$VENV_DIR/bin/activate"
    
    # 升级 pip
    pip install --upgrade pip > /dev/null 2>&1
    
    # 安装项目依赖
    pip install -e . || {
        print_error "依赖安装失败"
        print_info "尝试手动安装..."
        pip install docker microsandbox langchain langchain-deepseek langchain-ollama \
                    langfuse langgraph langgraph-checkpoint-sqlite langmem \
                    python-dotenv tenacity pydantic beautifulsoup4 lxml requests
    }
    
    print_success "依赖安装完成（虚拟环境）"
    
    # 创建激活脚本提示
    cat > activate_env.sh << 'EOF'
#!/bin/bash
# 激活虚拟环境的快捷脚本
source .venv/bin/activate
echo "✅ 虚拟环境已激活"
echo "运行: python main.py -t http://target.com"
EOF
    chmod +x activate_env.sh
    
    print_info "创建了激活脚本: ./activate_env.sh"
fi

# ==================== 4. 启动 Docker 容器 ====================
print_info "检查 Docker 容器..."

CONTAINER_NAME=$(grep "^DOCKER_CONTAINER_NAME" .env | cut -d '=' -f2)

if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    print_warning "容器 ${CONTAINER_NAME} 已存在"
    
    if docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
        print_success "容器正在运行"
    else
        print_info "启动容器..."
        docker start ${CONTAINER_NAME}
        print_success "容器已启动"
    fi
else
    print_info "创建并启动容器..."
    cd docker
    docker compose up -d
    cd ..
    print_success "容器创建完成"
fi

# ==================== 5. 验证 Ollama 连接（如果使用）====================
if grep -q "^LLM_BACKEND=ollama" .env; then
    print_info "验证 Ollama 连接..."
    
    OLLAMA_URL=$(grep "^OLLAMA_BASE_URL" .env | cut -d '=' -f2)
    
    if curl -s --connect-timeout 5 "${OLLAMA_URL}/api/tags" > /dev/null; then
        print_success "Ollama 连接成功"
        
        print_info "可用模型列表："
        curl -s "${OLLAMA_URL}/api/tags" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    for model in data.get('models', [])[:10]:
        print(f\"  - {model['name']} ({model['size'] / 1e9:.2f} GB)\")
except:
    print('  (无法解析模型列表)')
"
    else
        print_error "无法连接到 Ollama 服务器 (${OLLAMA_URL})"
        print_warning "请确保 Ollama 服务正在运行"
        print_info "继续部署，但运行时可能失败..."
    fi
fi

# ==================== 6. 完成提示 ====================
echo ""
print_success "部署完成！"
echo ""

if [ "$USE_UV" = true ]; then
    echo "接下来你可以："
    echo "  1. 单目标模式：uv run main.py -t http://target.com"
    echo "  2. 比赛模式：uv run main.py -api"
else
    echo "⚠️  重要：由于使用虚拟环境，运行前需要激活："
    echo ""
    echo "  方式 1：使用快捷脚本"
    echo "    source ./activate_env.sh"
    echo "    python main.py -t http://target.com"
    echo ""
    echo "  方式 2：手动激活"
    echo "    source .venv/bin/activate"
    echo "    python main.py -t http://target.com"
    echo ""
    echo "  方式 3：直接运行（推荐）"
    echo "    .venv/bin/python main.py -t http://target.com"
fi

echo ""
echo "日志位置："
echo "  - 主日志：logs/"
echo "  - 题目日志：logs/challenges/"
echo ""
echo "配置文件："
echo "  - .env：环境变量配置"
echo "  - pyproject.toml：项目依赖"
echo ""
print_info "祝你好运！🚀"
