#!/usr/bin/env python3
import sys
import os

def test_import():
    """测试 llama-cpp-python 是否能正常导入"""
    print("[1/3] 测试导入 llama-cpp-python...")
    try:
        from llama_cpp import Llama
        print("✓ llama-cpp-python 导入成功！")
        return Llama
    except ImportError as e:
        print(f"✗ 导入失败: {e}")
        print("请运行: pip install llama-cpp-python")
        return None

def test_model_exists(model_path):
    """测试模型文件是否存在"""
    print(f"\n[2/3] 检查模型文件: {model_path}")
    if os.path.exists(model_path):
        size_mb = os.path.getsize(model_path) / (1024 * 1024)
        print(f"✓ 模型文件存在！大小: {size_mb:.1f} MB")
        return True
    else:
        print(f"✗ 模型文件不存在: {model_path}")
        return False

def test_load_model(Llama, model_path):
    """测试加载模型"""
    print(f"\n[3/3] 尝试加载模型（这可能需要一些时间）...")
    try:
        llm = Llama(
            model_path=model_path,
            n_ctx=2048,
            n_batch=512,
            n_threads=4,
            verbose=True
        )
        print("✓ 模型加载成功！")
        
        # 简单测试生成
        print("\n进行简单的生成测试...")
        output = llm(
            "Hello, my name is",
            max_tokens=32,
            temperature=0.7,
            stream=False
        )
        
        if 'choices' in output and len(output['choices']) > 0:
            text = output['choices'][0].get('text', '')
            print(f"生成结果: Hello, my name is{text}")
        
        return True
    except Exception as e:
        print(f"✗ 模型加载失败: {e}")
        import traceback
        traceback.print_exc()
        return False

def main():
    print("=" * 60)
    print("llama-cpp-python 测试脚本")
    print("=" * 60)
    
    # 测试 1：导入
    Llama = test_import()
    if Llama is None:
        return 1
    
    # 测试 2：模型文件
    model_path = os.path.join(os.path.dirname(__file__), '..', 'assets', 'qwen2.5-0.5b-instruct-q4_k_m.gguf')
    model_path = os.path.abspath(model_path)
    
    if not test_model_exists(model_path):
        # 尝试找另一个模型
        model_path2 = os.path.join(os.path.dirname(__file__), '..', 'assets', 'qwen2.5-1.5b-instruct-q4_k_m.gguf')
        model_path2 = os.path.abspath(model_path2)
        if test_model_exists(model_path2):
            model_path = model_path2
        else:
            return 1
    
    # 测试 3：加载模型
    success = test_load_model(Llama, model_path)
    
    print("\n" + "=" * 60)
    if success:
        print("所有测试通过！🎉")
        return 0
    else:
        print("测试失败！")
        return 1

if __name__ == '__main__':
    sys.exit(main())
