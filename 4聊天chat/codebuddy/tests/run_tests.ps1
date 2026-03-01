# PowerShell测试运行脚本

Write-Host "运行测试套件..." -ForegroundColor Green
Write-Host "====================" -ForegroundColor Green

# 运行所有测试
pytest tests/ -v

# 运行测试并生成覆盖率报告
Write-Host ""
Write-Host "生成覆盖率报告..." -ForegroundColor Green
pytest tests/ --cov=. --cov-report=html --cov-report=term

Write-Host ""
Write-Host "测试完成！" -ForegroundColor Green
Write-Host "覆盖率报告在 htmlcov/index.html" -ForegroundColor Yellow
