#!/bin/bash

# 测试运行脚本

echo "运行测试套件..."
echo "===================="

# 运行所有测试
pytest tests/ -v

# 运行测试并生成覆盖率报告
echo ""
echo "生成覆盖率报告..."
pytest tests/ --cov=. --cov-report=html --cov-report=term

echo ""
echo "测试完成！"
echo "覆盖率报告在 htmlcov/index.html"
