import akshare as ak
import pandas as pd
from typing import List, Dict, Optional

class StockData:
    """股票数据获取类"""
    
    def get_stock_list(self) -> List[Dict]:
        """获取A股股票列表"""
        try:
            stock_list = ak.stock_zh_a_spot()
            return stock_list.to_dict('records')
        except Exception as e:
            return [{'error': str(e)}]
    
    def get_stock_quote(self, symbol: str) -> Dict:
        """获取股票实时行情"""
        try:
            stock_quote = ak.stock_zh_a_spot()
            stock_data = stock_quote[stock_quote['代码'] == symbol]
            if not stock_data.empty:
                return stock_data.iloc[0].to_dict()
            else:
                return {'error': '股票代码不存在'}
        except Exception as e:
            return {'error': str(e)}
    
    def get_stock_history(self, symbol: str, start_date: str, end_date: str, period: str = 'daily') -> List[Dict]:
        """获取股票历史数据"""
        try:
            if period == 'daily':
                stock_history = ak.stock_zh_a_daily(symbol=symbol, start_date=start_date, end_date=end_date)
            elif period == 'weekly':
                stock_history = ak.stock_zh_a_weekly(symbol=symbol, start_date=start_date, end_date=end_date)
            elif period == 'monthly':
                stock_history = ak.stock_zh_a_monthly(symbol=symbol, start_date=start_date, end_date=end_date)
            else:
                return [{'error': '不支持的周期类型'}]
            
            return stock_history.reset_index().to_dict('records')
        except Exception as e:
            return [{'error': str(e)}]
    
    def search_stock(self, keyword: str) -> List[Dict]:
        """根据关键词搜索股票"""
        try:
            stock_list = ak.stock_zh_a_spot()
            result = stock_list[(stock_list['代码'].str.contains(keyword)) | (stock_list['名称'].str.contains(keyword))]
            return result.to_dict('records')
        except Exception as e:
            return [{'error': str(e)}]