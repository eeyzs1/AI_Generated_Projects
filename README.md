# AI_Generated_Projects

开发前：
1. 需求定义
2. 整理成PRD（product requirements doc），定义验收标准(acceptance criteria, 做到什么程度算成功)
3. 定义视觉和页面框架
4. 明确项目边界和非功能需求（如性能、安全、可扩展性、成本等）
5. 锁定技术栈，越可验证越好（可控，资料更多）
6. 让AI出轻量化结构草案（架构分层，核心模块，数据模型，接口定义）
7. PRD,ARCH,PROJECT_STATE
8. 定开发规范，建参考资料
9. git，质量闸门

开发中：AI负责体力活，人负责边界和验收
1. 小步迭代，端到端切片（mvp）
2. 人类介入，主动拆分模块
3. 限制AI权限，只让AI改需要改的文件或者范围
4. 注意安全底线
5. 科学应对报错，两次无新增证据则停掉：1. 最小复现 2. 加日志加断点 3. 写小测试，锁定行为。让AI基于此去修


当你向使用此仓库时，由于使用了submodules，建议你使用以下方法之一来克隆仓库：
方法一：一步到位（推荐）
使用 --recurse-submodules 参数，Git 会自动克隆主仓库并初始化、更新所有子模块。
git clone --recurse-submodules git@github.com:eeyzs1/AI_Generated_Projects.git

方法二：亡羊补牢（如果你已经 Clone 了但发现子模块目录是空的）
如果你已经执行了普通的 git clone，不需要重新下载，可以在项目目录下执行以下命令来拉取子模块：
git submodule update --init --recursive