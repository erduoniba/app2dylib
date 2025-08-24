# CLAUDE.md

本文件为 Claude Code (claude.ai/code) 在此代码库中工作提供指导。

## 构建和开发命令

### 构建项目
```bash
# 构建 app2dylib 工具
make restore-symbol

# 清理构建产物
make clean

# 初始化 git 子模块（class-dump 依赖项所需）
git submodule update --init --recursive
```

### 使用方法

**手动方式：**
```bash
# 将 iOS 可执行文件转换为 dylib
./app2dylib -o output.dylib input_executable

# 对于多架构文件，先使用 lipo 提取单一架构
lipo input_fat_binary -thin arm64 -output input_arm64
./app2dylib -o output.dylib input_arm64
```

**自动化脚本方式：**
```bash
# 将 IPA 转换为 dylib，自动处理架构
./convert_app_to_dylib_simple.sh input.ipa output.dylib [架构]

# 使用示例
./convert_app_to_dylib_simple.sh MyApp.ipa libMyApp.dylib
./convert_app_to_dylib_simple.sh MyApp.ipa libMyApp.dylib arm64e
./convert_app_to_dylib_simple.sh /path/to/executable libMyApp.dylib

# 代码签名（iOS 部署推荐）
codesign -f -s - output.dylib
```

## 架构概述

这是一个逆向工程工具，将 iOS 应用程序可执行文件转换为动态库（.dylib），使其可以在其他应用程序中加载和使用。

### 核心组件

**主应用程序（`src/`）**
- `main.mm`：程序入口点，包含命令行参数解析和编排逻辑
- `app2dylib_template.h`：核心转换逻辑，使用 C++ 模板实现以处理 32 位和 64 位架构

**class-dump 子模块（`class-dump/`）**
- 外部依赖项（git 子模块），提供 Mach-O 文件解析功能
- 包含用于解析不同 Mach-O 加载命令的大量类（CDLoadCommand、CDMachOFile 等）
- 已修改以支持现代 iOS 加载命令，如 LC_BUILD_VERSION

### 转换过程

工具执行以下关键转换：
1. **文件类型更改**：在 Mach-O 头部将 MH_EXECUTE 转换为 MH_DYLIB
2. **内存布局调整**：将 PAGEZERO 段从大尺寸修改为 0x4000
3. **地址重定位**：更新所有内存地址以适应新的 PAGEZERO 大小
4. **动态库 ID**：添加带有适当安装路径的 LC_ID_DYLIB 加载命令
5. **符号表更新**：为新的内存布局调整符号地址

### 关键技术细节

- **基于模板**：使用 C++ 模板在单一代码库中处理 32 位和 64 位 Mach-O 格式
- **重定位跟踪**：维护 `rebasePointerSet` 来跟踪需要调整的地址
- **加载命令支持**：扩展以处理现代 iOS 加载命令，包括：
  - LC_BUILD_VERSION (0x32) 用于 iOS 版本信息
  - LC_DYLD_CHAINED_FIXUPS (0x80000033) 
  - LC_DYLD_EXPORTS_TRIE (0x80000034)
- **架构限制**：仅支持 arm64/armv7 单架构二进制文件（多架构文件必须先分离）

### 文件结构

- 构建系统使用带有 makefile 包装器的 Xcode 项目
- 依赖项通过 git 子模块管理
- 输出的 dylib 可以与 dlopen() 和标准动态加载 API 一起使用
- 生成的库需要代码签名才能在 iOS 上部署

### 平台兼容性

- 最初为较旧的 iOS 版本设计，但已扩展支持现代 iOS 二进制文件
- 通过传统的 LC_VERSION_MIN_* 和现代的 LC_BUILD_VERSION 命令处理版本检测
- 对于没有明确版本信息的二进制文件，默认使用 iOS dylib 路径