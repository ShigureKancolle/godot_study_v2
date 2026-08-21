# coding=utf-8

"""
通用 protobuf 编译脚本：使用 grpcio-tools 编译 .proto 文件
无需单独安装 protoc 编译器

使用方法：
    python compile_proto.py

配置说明：
    修改下方 INPUT_DIR 和 OUTPUT_DIR 两个变量即可
    - INPUT_DIR:  存放 .proto 文件的目录（会递归查找所有 .proto 文件）
    - OUTPUT_DIR: 编译后 .py 文件的输出目录
"""

import os
import sys
import glob
import argparse
import subprocess


# ==================== 用户配置区 ====================
# 唯一协议源在仓库根目录 protocol/。可以通过命令行参数覆盖，便于工具调用。
INPUT_DIR = "../../protocol"

# 编译后 Python 文件输出目录（相对于本脚本的路径，或绝对路径均可）
# 输出到 server/proto/generated/
OUTPUT_DIR = "./generated"
# ==================================================


def resolve_path(path: str) -> str:
    """
    将路径解析为绝对路径
    支持相对路径（相对于脚本所在目录）和绝对路径

    Args:
        path: 输入路径

    Returns:
        绝对路径
    """
    # 如果是相对路径，则基于脚本所在目录解析
    if not os.path.isabs(path):
        script_dir = os.path.dirname(os.path.abspath(__file__))
        path = os.path.join(script_dir, path)
    # 规范化路径（处理 ../ 和 ./ 等）
    return os.path.normpath(path)


def find_proto_files(input_dir: str) -> list:
    """
    递归查找目录下所有 .proto 文件

    Args:
        input_dir: 输入目录

    Returns:
        找到的 .proto 文件绝对路径列表
    """
    # 使用 glob 递归匹配所有 .proto 文件
    pattern = os.path.join(input_dir, "**", "*.proto")
    proto_files = glob.glob(pattern, recursive=True)
    return proto_files


def check_grpc_tools() -> bool:
    """
    检查是否安装了 grpcio-tools

    Returns:
        True 表示已安装，False 表示未安装
    """
    try:
        import grpc_tools  # noqa: F401
        return True
    except ImportError:
        return False


def compile_proto_files(input_dir: str, output_dir: str) -> bool:
    """
    编译指定目录下的所有 .proto 文件

    Args:
        input_dir:  proto 文件所在目录
        output_dir: 编译后文件输出目录

    Returns:
        True 表示编译成功，False 表示失败
    """
    # 查找所有 .proto 文件
    proto_files = find_proto_files(input_dir)

    if not proto_files:
        print(f"ERROR: no .proto files found in {input_dir}")
        print("   请检查 INPUT_DIR 配置是否正确")
        return False

    # 确保输出目录存在
    os.makedirs(output_dir, exist_ok=True)

    print("=" * 60)
    print("protobuf 编译工具")
    print("=" * 60)
    print(f"输入目录: {input_dir}")
    print(f"输出目录: {output_dir}")
    print(f"找到 {len(proto_files)} 个 .proto 文件:")
    for pf in proto_files:
        # 显示相对路径，更清晰
        rel_path = os.path.relpath(pf, input_dir)
        print(f"  - {rel_path}")
    print("-" * 60)

    # 构造 protoc 命令参数
    # -I: 指定 proto 源目录（作为 import 根目录）
    # --python_out: 指定 Python 文件输出目录
    cmd = [
        sys.executable, "-m", "grpc_tools.protoc",
        f"-I{input_dir}",
        f"--python_out={output_dir}",
    ]
    # 将所有 proto 文件追加到命令末尾
    cmd.extend(proto_files)

    try:
        # 执行编译命令
        result = subprocess.run(
            cmd,
            check=True,
            capture_output=True,
            text=True
        )

        # 统计生成的文件
        generated_files = glob.glob(os.path.join(output_dir, "**", "*_pb2.py"), recursive=True)

        print(f"OK: generated {len(generated_files)} protobuf file(s):")
        for gf in generated_files:
            rel_path = os.path.relpath(gf, output_dir)
            print(f"  {rel_path}")

        print()
        print("提示：如果输出目录不在 Python 路径中，")
        print("     请确保运行时能正确 import 这些生成的模块。")
        return True

    except subprocess.CalledProcessError as e:
        print("ERROR: protobuf compilation failed")
        print(f"错误信息: {e.stderr}")
        return False


def main():
    argument_parser = argparse.ArgumentParser(description="Compile the canonical protobuf schema for Python.")
    argument_parser.add_argument("--input", default=INPUT_DIR, help="Schema directory or a single .proto file")
    argument_parser.add_argument("--output", default=OUTPUT_DIR, help="Python generated-code output directory")
    args = argument_parser.parse_args()

    # 解析配置的路径为绝对路径
    input_path = resolve_path(args.input)
    output_dir = resolve_path(args.output)

    # protoc accepts a directory as import root. A file input uses its parent.
    if os.path.isfile(input_path):
        input_dir = os.path.dirname(input_path)
        proto_files = [input_path]
    else:
        input_dir = input_path
        proto_files = None

    # 检查输入目录是否存在
    if not os.path.isdir(input_dir):
        print(f"ERROR: input directory does not exist: {input_dir}")
        print("   请修改脚本顶部的 INPUT_DIR 配置")
        sys.exit(1)

    # 检查 grpcio-tools 是否安装
    if not check_grpc_tools():
        print("ERROR: grpcio-tools is not installed")
        print()
        print("请先安装依赖：")
        print("  pip install grpcio-tools")
        sys.exit(1)

    # 执行编译
    if proto_files is None:
        success = compile_proto_files(input_dir, output_dir)
    else:
        # Keep the single-file command-line path equivalent to directory mode.
        os.makedirs(output_dir, exist_ok=True)
        cmd = [sys.executable, "-m", "grpc_tools.protoc", f"-I{input_dir}", f"--python_out={output_dir}", *proto_files]
        result = subprocess.run(cmd, capture_output=True, text=True)
        if result.returncode != 0:
            print("ERROR: protobuf compilation failed")
            print(result.stderr)
            success = False
        else:
            print(f"OK: compiled {os.path.basename(input_path)}")
            success = True
    sys.exit(0 if success else 1)


if __name__ == "__main__":
    main()
