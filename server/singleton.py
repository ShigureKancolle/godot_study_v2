# coding = utf-8
import typing
from typing import TypeVar, Type, Optional, Generic

T = TypeVar("T")


class Singleton(Generic[T]):
    def __init__(self, cls: Type[T]):
        # 保存被装饰的类
        self._cls = cls
        # 存储唯一实例
        self._instance: Optional[T] = None

    def __call__(self, *args, **kwargs) -> T:
        """每次调用都返回一个新实例（普通构造）"""
        return self._cls(*args, **kwargs)

    def get(self, *args, **kwargs) -> T:
        """创建并获取单例（首次调用时创建）"""
        if self._instance is None:
            self._instance = self._cls(*args, **kwargs)
        return self._instance

    def get_ins(self) -> Optional[T]:
        """仅获取已存在的单例，若不存在返回 None"""
        return self._instance