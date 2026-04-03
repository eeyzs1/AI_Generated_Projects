#!/usr/bin/env python3
import sys
import json
import os
import argparse
from typing import Optional, Generator
from pathlib import Path


class LlmServer:
    def __init__(self, model_path: str):
        self.model_path = model_path
        self.llama = None
        self._load_model()

    def _load_model(self):
        """加载 LLM 模型"""
        try:
            from llama_cpp import Llama
            
            print(f"[INFO] 正在加载模型: {self.model_path}", file=sys.stderr)
            
            self.llama = Llama(
                model_path=self.model_path,
                n_ctx=2048,
                n_batch=512,
                n_threads=4,
                verbose=True
            )
            
            print("[INFO] 模型加载成功！", file=sys.stderr)
            
        except ImportError:
            print("[ERROR] 请先安装: pip install llama-cpp-python", file=sys.stderr)
            sys.exit(1)
        except Exception as e:
            print(f"[ERROR] 模型加载失败: {e}", file=sys.stderr)
            sys.exit(1)

    def generate(self, prompt: str, max_tokens: int = 256, temperature: float = 0.1, 
                top_p: float = 0.9, top_k: int = 40, repeat_penalty: float = 1.1) -> Generator[str, None, None]:
        """生成文本（流式）"""
        if self.llama is None:
            yield "[ERROR] 模型未加载"
            return

        try:
            output = self.llama(
                prompt,
                max_tokens=max_tokens,
                temperature=temperature,
                top_p=top_p,
                top_k=top_k,
                repeat_penalty=repeat_penalty,
                stream=True
            )
            
            for chunk in output:
                if 'choices' in chunk and len(chunk['choices']) > 0:
                    text = chunk['choices'][0].get('text', '')
                    if text:
                        yield text
                        
        except Exception as e:
            yield f"[ERROR] 生成失败: {e}"

    def run(self):
        """运行服务器，从 stdin 读取命令，向 stdout 输出"""
        print("[READY]", file=sys.stderr)
        
        while True:
            try:
                line = sys.stdin.readline()
                if not line:
                    break
                
                line = line.strip()
                if not line:
                    continue
                
                try:
                    request = json.loads(line)
                    action = request.get('action')
                    
                    if action == 'generate':
                        prompt = request.get('prompt', '')
                        params = request.get('params', {})
                        
                        print("[GENERATING]", file=sys.stderr)
                        
                        for token in self.generate(
                            prompt,
                            max_tokens=params.get('maxTokens', 256),
                            temperature=params.get('temperature', 0.1),
                            top_p=params.get('topP', 0.9),
                            top_k=params.get('topK', 40),
                            repeat_penalty=params.get('repeatPenalty', 1.1)
                        ):
                            # 每个 token 一行输出
                            print(json.dumps({'type': 'token', 'data': token}), flush=True)
                        
                        print(json.dumps({'type': 'done'}), flush=True)
                        
                    elif action == 'ping':
                        print(json.dumps({'type': 'pong'}), flush=True)
                        
                    elif action == 'exit':
                        print(json.dumps({'type': 'exiting'}), flush=True)
                        break
                        
                except json.JSONDecodeError as e:
                    print(json.dumps({'type': 'error', 'data': f'JSON 解析错误: {e}'}), flush=True)
                    
            except KeyboardInterrupt:
                break
            except Exception as e:
                print(json.dumps({'type': 'error', 'data': str(e)}), flush=True)


def main():
    parser = argparse.ArgumentParser(description='LLM 本地推理服务器')
    parser.add_argument('--model', required=True, help='GGUF 模型文件路径')
    args = parser.parse_args()
    
    if not os.path.exists(args.model):
        print(f"[ERROR] 模型文件不存在: {args.model}", file=sys.stderr)
        sys.exit(1)
    
    server = LlmServer(args.model)
    server.run()


if __name__ == '__main__':
    main()
