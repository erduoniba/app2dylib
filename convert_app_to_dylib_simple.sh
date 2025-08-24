#!/bin/bash

# app2dylib 简化转换脚本
# 支持从 IPA 文件到 dylib 的完整转换流程

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

show_usage() {
    echo "Usage: $0 <input_file> <output_file> [architecture]"
    echo ""
    echo "Arguments:"
    echo "  input_file    输入文件 (IPA 或 Mach-O 可执行文件)"
    echo "  output_file   输出 dylib 文件路径"
    echo "  architecture  指定架构 (arm64, arm64e, armv7) [默认: arm64]"
    echo ""
    echo "Examples:"
    echo "  $0 app.ipa libApp.dylib"
    echo "  $0 app.ipa libApp.dylib arm64e"
    echo "  $0 /path/to/executable libApp.dylib"
}

main() {
    local input_file="$1"
    local output_file="$2"
    local arch="${3:-arm64}"
    
    # 检查参数
    if [ $# -lt 2 ]; then
        show_usage
        exit 1
    fi
    
    if [ ! -f "$input_file" ]; then
        print_error "输入文件不存在: $input_file"
        exit 1
    fi
    
    print_info "开始转换流程"
    print_info "输入文件: $input_file"
    print_info "输出文件: $output_file"
    print_info "目标架构: $arch"
    
    # 检查 app2dylib 工具
    if [ ! -f "./app2dylib" ]; then
        print_info "构建 app2dylib 工具..."
        make restore-symbol
    fi
    
    local temp_dir="./temp_convert_$$"
    local executable_file="$input_file"
    local cleanup_needed=false
    
    # 处理 IPA 文件
    if [[ "$input_file" == *.ipa ]]; then
        print_info "检测到 IPA 文件，正在提取..."
        
        mkdir -p "$temp_dir"
        unzip -q "$input_file" -d "$temp_dir"
        
        # 查找可执行文件
        local app_dir=$(find "$temp_dir/Payload" -name "*.app" -type d | head -n 1)
        if [ -z "$app_dir" ]; then
            print_error "找不到 .app 目录"
            exit 1
        fi
        
        local app_name=$(basename "$app_dir" .app)
        executable_file="$app_dir/$app_name"
        
        if [ ! -f "$executable_file" ]; then
            print_error "找不到可执行文件: $executable_file"
            exit 1
        fi
        
        print_success "IPA 提取完成: $app_name"
        cleanup_needed=true
    fi
    
    # 检查文件架构
    print_info "检查文件架构..."
    local file_info=$(file "$executable_file")
    echo "$file_info"
    
    local final_executable="$executable_file"
    
    if echo "$file_info" | grep -q "universal binary"; then
        print_info "检测到多架构文件，分离 $arch 架构..."
        
        # 检查是否支持指定架构
        if ! lipo -info "$executable_file" | grep -q "$arch"; then
            print_error "文件不支持 $arch 架构"
            lipo -info "$executable_file"
            exit 1
        fi
        
        final_executable="$temp_dir/executable_$arch"
        lipo "$executable_file" -thin "$arch" -output "$final_executable"
        print_success "架构分离完成"
        cleanup_needed=true
    fi
    
    # 转换为 dylib
    print_info "转换为 dylib..."
    
    # 创建输出目录
    mkdir -p "$(dirname "$output_file")"
    
    # 执行转换
    if ./app2dylib "$final_executable" -o "$output_file"; then
        print_success "转换完成: $output_file"
        
        # 显示文件信息
        ls -lh "$output_file"
        
        local size=$(stat -f%z "$output_file" 2>/dev/null || stat -c%s "$output_file" 2>/dev/null)
        print_info "dylib 文件大小: $(echo $size | awk '{printf "%.2f MB", $1/1024/1024}')"
        
        # 验证 dylib 文件格式
        if dd if="$output_file" skip=60 bs=1 count=8 2>/dev/null | hexdump -C | grep -q "cf fa ed fe"; then
            print_success "dylib 文件格式验证通过"
        fi
        
    else
        print_error "转换失败"
        cleanup_needed=true
        exit 1
    fi
    
    # 清理临时文件
    if [ "$cleanup_needed" = true ]; then
        print_info "清理临时文件..."
        rm -rf "$temp_dir"
    fi
    
    print_success "转换流程完成！"
    print_warning "提示: 生成的 dylib 需要代码签名才能在 iOS 设备上使用"
    print_info "代码签名命令: codesign -f -s - '$output_file'"
}

main "$@"