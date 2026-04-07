#!/usr/bin/env python3
import sys
import json
import os
import argparse
import tarfile
import time
import socket
from typing import Optional, Generator, Dict, Any
from pathlib import Path
from functools import lru_cache
import urllib.request


def _clean_text(text: str) -> str:
    """清理文本中的无效代理对字符"""
    try:
        result = text.encode('utf-8', errors='replace').decode('utf-8')
        result = ''.join(c for c in result if not (0xd800 <= ord(c) <= 0xdfff))
        return result
    except:
        return str(text)


def check_internet_access(host: str, port: int = 443, timeout: int = 5) -> bool:
    """
    检查是否能连接到指定主机
    
    Args:
        host: 主机名
        port: 端口
        timeout: 超时时间（秒）
    
    Returns:
        是否能连接
    """
    try:
        socket.setdefaulttimeout(timeout)
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        result = sock.connect_ex((host, port))
        sock.close()
        return result == 0
    except:
        return False


def check_huggingface_access() -> bool:
    """检查是否能访问 Hugging Face"""
    return check_internet_access('huggingface.co', 443, timeout=3)


def check_hf_mirror_access() -> bool:
    """检查是否能访问 HF 镜像站"""
    return check_internet_access('hf-mirror.com', 443, timeout=3)


def check_modelscope_access() -> bool:
    """检查是否能访问 ModelScope"""
    return check_internet_access('modelscope.cn', 443, timeout=3)


def get_best_download_source() -> str:
    """
    自动选择最佳下载源
    
    Returns:
        'huggingface' 或 'modelscope'
    """
    print("[INFO] 正在检测最佳下载源...", file=sys.stderr)
    
    if check_huggingface_access():
        print("[INFO] 可以访问 Hugging Face", file=sys.stderr)
        return 'huggingface'
    
    if check_modelscope_access():
        print("[INFO] 可以访问 ModelScope", file=sys.stderr)
        return 'modelscope'
    
    print("[WARNING] 无法访问任何下载源", file=sys.stderr)
    return 'modelscope'


def get_model_repo_id(model_type: str, source: str) -> str:
    """
    根据模型类型和下载源获取仓库 ID
    
    Args:
        model_type: 'opus_mt_en_zh' 或 'opus_mt_zh_en'
        source: 下载源
    
    Returns:
        仓库 ID
    """
    if source.startswith('huggingface'):
        if model_type == 'opus_mt_en_zh':
            return 'Helsinki-NLP/opus-mt-en-zh'
        elif model_type == 'opus_mt_zh_en':
            return 'Helsinki-NLP/opus-mt-zh-en'
    elif source == 'modelscope':
        if model_type == 'opus_mt_en_zh':
            return 'AI-ModelScope/opus-mt-en-zh'
        elif model_type == 'opus_mt_zh_en':
            return 'AI-ModelScope/opus-mt-zh-en'
    
    raise ValueError(f"Unsupported model type or source: {model_type}, {source}")


class OpusMtTranslator:
    """OPUS-MT 翻译器封装 - 支持本地模型目录"""
    
    def __init__(self, model_dir: Optional[str] = None):
        """
        初始化翻译器
        
        Args:
            model_dir: 本地模型根目录（包含 opus-mt-en-zh/ 等子目录）
        """
        self.model_dir = model_dir
        self.models = {}  # 缓存已加载的模型
        self.tokenizers = {}  # 缓存已加载的分词器
    
    def _get_model_key(self, source_lang: str, target_lang: str) -> str:
        """生成模型缓存 key"""
        return f"{source_lang}-{target_lang}"
    
    def _get_model_folder_name(self, source_lang: str, target_lang: str) -> str:
        """获取模型文件夹名称"""
        if source_lang == 'en' and target_lang == 'zh':
            return 'opus-mt-en-zh'
        elif source_lang == 'zh' and target_lang == 'en':
            return 'opus-mt-zh-en'
        else:
            raise ValueError(f"不支持的语言对: {source_lang}->{target_lang}")
    
    def _load_model(self, source_lang: str, target_lang: str):
        """加载模型和分词器"""
        from transformers import MarianMTModel, MarianTokenizer
        
        key = self._get_model_key(source_lang, target_lang)
        
        if key in self.models and key in self.tokenizers:
            return
        
        folder_name = self._get_model_folder_name(source_lang, target_lang)
        
        if self.model_dir is None:
            raise ValueError("模型目录未设置，请先下载模型")
        
        model_path = Path(self.model_dir) / folder_name
        
        if not model_path.exists():
            raise FileNotFoundError(f"模型目录不存在: {model_path}")
        
        print(f"[INFO] 正在加载 OPUS-MT 模型: {model_path}", file=sys.stderr)
        
        self.tokenizers[key] = MarianTokenizer.from_pretrained(str(model_path))
        self.models[key] = MarianMTModel.from_pretrained(str(model_path))
        
        print(f"[INFO] OPUS-MT 模型加载成功！", file=sys.stderr)
    
    @lru_cache(maxsize=1000)
    def translate(
        self,
        text: str,
        source_lang: str = 'en',
        target_lang: str = 'zh',
        max_length: int = 512
    ) -> str:
        """
        翻译文本
        
        Args:
            text: 待翻译文本
            source_lang: 源语言代码 ('en' 或 'zh')
            target_lang: 目标语言代码 ('zh' 或 'en')
            max_length: 最大生成长度
        
        Returns:
            翻译后的文本
        """
        try:
            self._load_model(source_lang, target_lang)
            
            key = self._get_model_key(source_lang, target_lang)
            tokenizer = self.tokenizers[key]
            model = self.models[key]
            
            cleaned_text = _clean_text(text.strip())
            if not cleaned_text:
                return ''
            
            inputs = tokenizer(
                cleaned_text,
                return_tensors="pt",
                padding=True,
                truncation=True,
                max_length=max_length
            )
            
            translated = model.generate(
                **inputs,
                max_length=max_length,
                num_beams=4,
                early_stopping=True
            )
            
            result = tokenizer.decode(translated[0], skip_special_tokens=True)
            return _clean_text(result.strip())
            
        except Exception as e:
            print(f"[ERROR] OPUS-MT 翻译失败: {e}", file=sys.stderr)
            import traceback
            traceback.print_exc(file=sys.stderr)
            raise


class StarDictManager:
    """StarDict 词典管理器（保持原有功能）"""
    pass


def download_model_from_hub(repo_id: str, save_path: str, on_progress=None) -> bool:
    """
    从 Hugging Face Hub 下载模型
    
    Args:
        repo_id: 模型仓库 ID (如 'Helsinki-NLP/opus-mt-en-zh')
        save_path: 保存路径
        on_progress: 进度回调函数 (received_bytes, total_bytes)
    
    Returns:
        是否成功
    """
    try:
        from huggingface_hub import snapshot_download
        
        print(f"[INFO] 正在下载模型: {repo_id}", file=sys.stderr)
        
        def progress_callback(current, total):
            if on_progress:
                on_progress(current, total)
        
        snapshot_download(
            repo_id=repo_id,
            local_dir=save_path,
            local_dir_use_symlinks=False,
        )
        
        print(f"[INFO] 模型下载完成: {save_path}", file=sys.stderr)
        return True
    except Exception as e:
        print(f"[ERROR] 模型下载失败: {e}", file=sys.stderr)
        import traceback
        traceback.print_exc(file=sys.stderr)
        return False


def download_model_from_modelscope(repo_id: str, save_path: str, on_progress=None) -> bool:
    """
    从 ModelScope（阿里）下载模型
    
    Args:
        repo_id: 模型仓库 ID (如 'AI-ModelScope/opus-mt-en-zh')
        save_path: 保存路径
        on_progress: 进度回调函数 (received_bytes, total_bytes)
    
    Returns:
        是否成功
    """
    try:
        from modelscope import snapshot_download
        
        print(f"[INFO] 正在从 ModelScope 下载模型: {repo_id}", file=sys.stderr)
        
        def progress_callback(current, total):
            if on_progress:
                on_progress(current, total)
        
        snapshot_download(
            model_id=repo_id,
            cache_dir=save_path,
        )
        
        # ModelScope 下载后需要移动文件到正确位置
        model_dir = Path(save_path)
        for item in model_dir.iterdir():
            if item.is_dir() and item.name.startswith('hub'):
                # 查找实际的模型目录
                for subitem in item.rglob('config.json'):
                    actual_model_dir = subitem.parent
                    # 移动所有文件到 save_path
                    for file in actual_model_dir.iterdir():
                        if file.is_file():
                            file.rename(model_dir / file.name)
                break
        
        print(f"[INFO] 模型下载完成: {save_path}", file=sys.stderr)
        return True
    except Exception as e:
        print(f"[ERROR] 从 ModelScope 下载失败: {e}", file=sys.stderr)
        import traceback
        traceback.print_exc(file=sys.stderr)
        return False


class LlmServer:
    def __init__(self, model_dir: Optional[str] = None):
        self.model_dir = model_dir
        self.opus_mt = OpusMtTranslator(model_dir)
        self.stardict = StarDictManager()
    
    def translate_with_opus_mt(
        self,
        text: str,
        source_lang: str = 'en',
        target_lang: str = 'zh'
    ) -> str:
        """使用 OPUS-MT 翻译"""
        return self.opus_mt.translate(text, source_lang, target_lang)
    
    def download_model(
        self,
        model_type: str,
        save_path: str,
        source: Optional[str] = None,
        auto_detect: bool = True
    ) -> Dict[str, Any]:
        """
        下载模型（自动检测最佳源）
        
        Args:
            model_type: 模型类型
            save_path: 保存路径
            source: 强制指定下载源 ('huggingface' 或 'modelscope')
            auto_detect: 是否自动检测
        
        Returns:
            结果字典
        """
        actual_source = source
        
        if auto_detect or actual_source is None:
            actual_source = get_best_download_source()
        
        try:
            repo_id = get_model_repo_id(model_type, actual_source)
            
            print(f"[DOWNLOAD] {actual_source} {repo_id} -> {save_path}", file=sys.stderr)
            
            success = False
            if actual_source == 'modelscope':
                success = download_model_from_modelscope(repo_id, save_path)
            else:
                success = download_model_from_hub(repo_id, save_path)
            
            return {
                'success': success,
                'source': actual_source
            }
        except Exception as e:
            print(f"[ERROR] 下载模型失败: {e}", file=sys.stderr)
            import traceback
            traceback.print_exc(file=sys.stderr)
            return {
                'success': False,
                'error': str(e),
                'source': actual_source
            }
    
    def check_download_sources(self) -> Dict[str, bool]:
        """检查各下载源的可用性"""
        return {
            'huggingface': check_huggingface_access(),
            'modelscope': check_modelscope_access(),
        }
    
    def run(self):
        print("[READY]", file=sys.stderr)
        print(json.dumps({'type': 'ready'}, ensure_ascii=True), flush=True)
        
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
                    
                    if action == 'translate_opus_mt':
                        text = request.get('text', '')
                        source_lang = request.get('sourceLang', 'en')
                        target_lang = request.get('targetLang', 'zh')
                        
                        print(f"[OPUS-MT] {source_lang}->{target_lang}: {text[:50]}...", file=sys.stderr)
                        
                        try:
                            result = self.translate_with_opus_mt(text, source_lang, target_lang)
                            output_dict = {
                                'type': 'translate_result',
                                'data': {
                                    'success': True,
                                    'text': result
                                }
                            }
                        except Exception as e:
                            output_dict = {
                                'type': 'translate_result',
                                'data': {
                                    'success': False,
                                    'error': str(e)
                                }
                            }
                        
                        print(json.dumps(output_dict, ensure_ascii=True), flush=True)
                    
                    elif action == 'download_model':
                        model_type = request.get('modelType', '')
                        save_path = request.get('savePath', '')
                        source = request.get('source')
                        auto_detect = request.get('autoDetect', True)
                        
                        result = self.download_model(model_type, save_path, source, auto_detect)
                        
                        output_dict = {
                            'type': 'download_result',
                            'data': result
                        }
                        
                        print(json.dumps(output_dict, ensure_ascii=True), flush=True)
                    
                    elif action == 'check_sources':
                        sources = self.check_download_sources()
                        output_dict = {
                            'type': 'sources_result',
                            'data': sources
                        }
                        print(json.dumps(output_dict, ensure_ascii=True), flush=True)
                    
                    elif action == 'ping':
                        print(json.dumps({'type': 'pong'}, ensure_ascii=True), flush=True)
                        
                    elif action == 'exit':
                        break
                    
                    else:
                        print(json.dumps({
                            'type': 'error',
                            'data': f'Unknown action: {action}'
                        }, ensure_ascii=True), flush=True)
                        
                except json.JSONDecodeError as e:
                    print(json.dumps({
                        'type': 'error',
                        'data': f'JSON decode error: {str(e)}'
                    }, ensure_ascii=True), flush=True)
                    
            except KeyboardInterrupt:
                break
            except Exception as e:
                print(json.dumps({
                    'type': 'error',
                    'data': f'Server error: {str(e)}'
                }, ensure_ascii=True), flush=True)


def main():
    parser = argparse.ArgumentParser(description='OPUS-MT 本地翻译服务器')
    parser.add_argument('--model-dir', help='OPUS-MT 模型根目录')
    args = parser.parse_args()
    
    server = LlmServer(args.model_dir)
    server.run()


if __name__ == '__main__':
    main()
