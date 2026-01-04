# Arch WSL 自动化配置工具 v3.0

## 🎯 设计理念

**高内聚低耦合 + 可插拔架构**

从 700+ 行精简到 **450 行**，代码量减少 **35%**，同时提升可维护性。

## 🏗️ 核心架构

### 设计模式

```
策略模式 (Strategy)      → 每个功能是独立策略
命令模式 (Command)       → 功能可单独执行
注册器模式 (Registry)    → 自动发现和管理功能
上下文模式 (Context)     → 数据传递容器
```

### 模块关系图

```
┌─────────────────────────────────────────┐
│  App (主控制器)                          │
│  - 流程编排                              │
│  - 菜单管理                              │
└──────────────┬──────────────────────────┘
               │
               ├──→ Context (上下文对象)
               │    - 数据容器
               │    - 零逻辑
               │
               ├──→ Registry (注册中心)
               │    - 功能发现
               │    - 自动注册
               │
               └──→ Feature (功能基类)
                    ↓
    ┌───────────────┴───────────────┐
    │  具体功能 (可插拔)              │
    ├─ UpdateSystem                 │
    ├─ InstallBase                  │
    ├─ CreateUser                   │
    ├─ ConfigureWSL                 │
    ├─ InstallOhMyZsh               │
    ├─ ...                          │
    └─────────────────────────────────┘
         ↑
         └── 使用 @Registry.register 装饰器自动注册
```

## 📦 模块职责

### 1. 配置模块 (Cfg)
```python
class Cfg:
    PKG_BASE = [...]      # 基础包列表
    PKG_OPT = [...]       # 可选包列表
    WSL_CONF = "..."      # 路径配置
    OMZ_URL = "..."       # URL 配置
```
- ✅ **纯数据**，零依赖
- ✅ 所有配置集中管理
- ✅ 修改配置不影响逻辑

### 2. 上下文对象 (Context)
```python
@dataclass
class Context:
    username: str
    password: str
    shell: str
    ...
```
- ✅ **数据容器**，无逻辑
- ✅ 使用 dataclass 简化
- ✅ 在模块间传递数据

### 3. 工具函数（纯函数）
```python
run()          # 执行命令
exists()       # 检查命令
user_exists()  # 检查用户
log()          # 彩色日志
```
- ✅ **无状态**，纯函数
- ✅ 可独立测试
- ✅ 可复用

### 4. 功能基类 (Feature)
```python
class Feature(ABC):
    @abstractmethod
    def execute(self): pass
    
    @property
    @abstractmethod
    def name(self) -> str: pass
    
    @property
    def needs_user(self) -> bool: return False
    
    @property
    def order(self) -> int: return 50
```
- ✅ **抽象接口**定义契约
- ✅ 默认实现通用属性
- ✅ 子类只需实现核心逻辑

### 5. 注册中心 (Registry)
```python
class Registry:
    @classmethod
    def register(cls, key: str, order: int = 50):
        """装饰器：自动注册功能"""
```
- ✅ **自动发现**功能
- ✅ 解耦功能与主控
- ✅ 支持执行顺序

### 6. 具体功能实现
```python
@Registry.register('update', order=10)
class UpdateSystem(Feature):
    name = "系统更新"
    
    def execute(self):
        run("pacman -Syyu --noconfirm")
```
- ✅ **装饰器注册**，自动发现
- ✅ 独立封装，互不依赖
- ✅ 可单独测试

### 7. 主控制器 (App)
```python
class App:
    def run(self):
        self._menu()        # 菜单
        self._collect_data()  # 收集数据
        self._execute()     # 执行
        self._done()        # 完成
```
- ✅ **流程编排**
- ✅ 不关心具体功能实现
- ✅ 职责单一

## 🔥 核心优势

### 1. 高内聚
每个模块职责明确：
- `Cfg` → 配置
- `Context` → 数据
- `Feature` → 功能
- `Registry` → 管理
- `App` → 流程

### 2. 低耦合
- 功能模块之间**零依赖**
- 通过 `Context` 传递数据，不直接调用
- 通过 `Registry` 注册，不硬编码

### 3. 可扩展
添加新功能只需 **3 行代码**：

```python
@Registry.register('docker', order=45)
class InstallDocker(Feature):
    name = "安装 Docker"
    needs_user = True  # 可选
    
    def execute(self):
        section(self.name)
        run("pacman -S --noconfirm docker docker-compose")
        log("✓ 完成", 'G')
```

**完成！** 无需修改其他任何代码。

### 4. 可测试
```python
# 测试单个功能
ctx = Context(username="test", password="123")
feature = UpdateSystem(ctx)
feature.execute()

# 测试工具函数
assert exists("python3") == True
assert user_exists("root") == True
```

## 📊 代码对比

| 指标 | v2.0 (旧版) | v3.0 (新版) | 改进 |
|------|-------------|-------------|------|
| 代码行数 | 700+ | 450 | -35% |
| 类数量 | 9 | 4 (基础) + N (功能) | 模块化 |
| 添加功能 | 修改 3 处 | 添加 1 个类 | **简化 3 倍** |
| 耦合度 | 中等 | 极低 | ✅ |
| 可测试性 | 困难 | 简单 | ✅ |

## 🚀 使用方法

### 基础使用
```bash
sudo bash bootstrap.sh
```

### 快速上手
```bash
# 在菜单中选择
[1-11] 单个/多个功能
[A]    全部安装
```

## 🔧 自定义配置

### 修改包列表
```python
# 在 Cfg 类中修改
class Cfg:
    PKG_BASE = [
        "base-devel",
        "git",
        "your-package",  # 添加你的包
    ]
```

### 添加新功能（完整示例）

#### 示例 1：安装 Docker
```python
@Registry.register('docker', order=45)
class InstallDocker(Feature):
    name = "安装 Docker"
    
    def execute(self):
        section(self.name)
        run("pacman -S --noconfirm docker docker-compose")
        run("systemctl enable docker")
        log("✓ 完成", 'G')
```

#### 示例 2：配置 Vim
```python
@Registry.register('vim', order=35)
class ConfigureVim(Feature):
    name = "配置 Vim"
    needs_user = True  # 需要用户信息
    
    def execute(self):
        section(self.name)
        vimrc = f"{self.ctx.user_home}/.vimrc"
        config = """
set number
set autoindent
syntax on
"""
        with open(vimrc, 'w') as f:
            f.write(config)
        log("✓ 完成", 'G')
```

#### 示例 3：安装 Node.js (需要 yay)
```python
@Registry.register('nodejs', order=42)
class InstallNodeJS(Feature):
    name = "安装 Node.js"
    needs_user = True
    order = 42  # 在 yay 之后执行
    
    def execute(self):
        section(self.name)
        if not exists('yay'):
            log("需要先安装 Yay", 'R')
            return
        run("yay -S --noconfirm nodejs npm", user=self.ctx.username)
        log("✓ 完成", 'G')
```

## 🎨 设计原则

### SOLID 原则应用

1. **S - 单一职责 (Single Responsibility)**
   - 每个类只做一件事
   - `Cfg` 只管配置，`Feature` 只管功能

2. **O - 开闭原则 (Open/Closed)**
   - 对扩展开放：添加新功能无需修改现有代码
   - 对修改封闭：核心框架稳定

3. **L - 里氏替换 (Liskov Substitution)**
   - 所有功能继承 `Feature`，可互相替换

4. **I - 接口隔离 (Interface Segregation)**
   - `Feature` 接口最小化
   - 可选属性用 property 实现

5. **D - 依赖倒置 (Dependency Inversion)**
   - 依赖抽象 (`Feature`)，不依赖具体实现
   - 通过 `Context` 传递数据，不直接依赖

## 📝 设计模式详解

### 1. 策略模式
```python
# 每个功能是独立策略
class UpdateSystem(Feature): ...
class InstallBase(Feature): ...
```

### 2. 命令模式
```python
# 每个功能封装为可执行命令
feature.execute()
```

### 3. 注册器模式
```python
# 自动发现和注册
@Registry.register('key')
class MyFeature(Feature): ...
```

### 4. 模板方法模式
```python
# Feature 基类定义模板
class Feature(ABC):
    def execute(self): pass  # 子类实现
    @property
    def name(self): pass     # 子类实现
```

## 🧪 测试示例

```python
# test_features.py
import unittest

class TestFeatures(unittest.TestCase):
    def test_update_system(self):
        ctx = Context()
        feature = UpdateSystem(ctx)
        self.assertEqual(feature.name, "系统更新")
    
    def test_user_creation(self):
        ctx = Context(username="test", password="123")
        feature = CreateUser(ctx)
        self.assertTrue(feature.needs_user)
```

## 📚 进阶用法

### 动态加载功能
```python
# 从配置文件加载要执行的功能
with open('features.txt') as f:
    features_to_run = f.read().split(',')

app = App()
app.selected = features_to_run
app._execute()
```

### 命令行参数支持
```python
import argparse

parser = argparse.ArgumentParser()
parser.add_argument('-f', '--features', help='功能列表')
args = parser.parse_args()

if args.features:
    app.selected = args.features.split(',')
```

## 🔒 最佳实践

1. **功能独立**：每个功能不依赖其他功能
2. **幂等性**：重复执行功能不会出错（已安装则跳过）
3. **错误处理**：失败时允许继续或中断
4. **日志清晰**：使用彩色日志便于调试
5. **顺序控制**：使用 `order` 属性控制执行顺序

## 🆚 对比旧版

### 旧版问题
- ❌ 类之间相互调用，耦合度高
- ❌ 添加功能需要修改多处代码
- ❌ 硬编码功能列表
- ❌ 难以测试

### 新版优势
- ✅ 模块独立，零耦合
- ✅ 装饰器注册，自动发现
- ✅ 添加功能只需一个类
- ✅ 易于测试和维护

---

**Enjoy Clean Code! 🎉**

