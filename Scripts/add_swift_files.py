#!/usr/bin/env python3
"""把新增的 Swift 文件注册到 StressWatch.xcodeproj。

用法：
    python3 Scripts/add_swift_files.py StressWatch/Core/Analysis/Metrics/DailyHealthMetrics.swift ...

规则：
- 路径以 ``StressWatchTests/`` 开头 → 加入 StressWatchTests target
- 其余（``StressWatch/...``）        → 加入 StressWatch app target
- 自动创建缺失的中间 PBXGroup，并按路径维护分组层级
- ID 由路径哈希生成，因此**可重复执行**（已存在则跳过）
- 修改前自动备份 project.pbxproj

设计动机：本轮升级会持续新增 engine 文件（T1.x~T8.x 共约 40 个），
手工编辑 pbxproj 易错且不可复现。
"""
from __future__ import annotations

import hashlib
import pathlib
import shutil
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
PBX = ROOT / "StressWatch.xcodeproj" / "project.pbxproj"

APP_TARGET_SOURCES_PHASE = "A30000000000000000000002"   # StressWatch Sources
TEST_TARGET_SOURCES_PHASE = "C30000000000000000000001"  # StressWatchTests Sources

APP_ROOT_GROUP = "A40000000000000000000002"   # StressWatch
TEST_ROOT_GROUP = "C40000000000000000000001"  # StressWatchTests


def oid(salt: str, key: str) -> str:
    """确定性 24 位十六进制 ID（首字母固定，避免以数字开头）。"""
    digest = hashlib.sha256(f"{salt}:{key}".encode()).hexdigest().upper()
    return ("F" if salt == "build" else "G" if salt == "ref" else "H") + digest[:23]


def insert_before_end(src: str, section: str, block: str) -> str:
    marker = f"/* End {section} section */"
    idx = src.find(marker)
    if idx == -1:
        sys.exit(f"FATAL: marker not found: {marker}")
    return src[:idx] + block + src[idx:]


def ensure_group(src: str, parent_id: str, name: str, group_key: str) -> tuple[str, str]:
    """在 parent 下找到（或创建）名为 name 的 PBXGroup，返回 (group_id, src)。"""
    gid = oid("group", group_key)
    if f"{gid} /* {name} */ = {{" in src:
        return gid, src

    # 在 parent 的 children 里插入
    anchor = f"{parent_id} /* "
    pidx = src.find(anchor)
    if pidx == -1:
        sys.exit(f"FATAL: parent group {parent_id} not found")
    child_marker = "\t\t\tchildren = (\n"
    cidx = src.find(child_marker, pidx)
    if cidx == -1:
        sys.exit(f"FATAL: children list not found in group {parent_id}")
    insert_at = cidx + len(child_marker)
    src = src[:insert_at] + f"\t\t\t\t{gid} /* {name} */,\n" + src[insert_at:]

    block = (
        f"\t\t{gid} /* {name} */ = {{\n"
        f"\t\t\tisa = PBXGroup;\n"
        f"\t\t\tchildren = (\n"
        f"\t\t\t);\n"
        f"\t\t\tpath = {name};\n"
        f"\t\t\tsourceTree = \"<group>\";\n"
        f"\t\t}};\n"
    )
    src = insert_before_end(src, "PBXGroup", block)
    return gid, src


def register(src: str, rel_path: str) -> str:
    if rel_path.startswith("StressWatchTests/"):
        root_group = TEST_ROOT_GROUP
        sources_phase = TEST_TARGET_SOURCES_PHASE
        rel_inside_root = rel_path[len("StressWatchTests/"):]
    elif rel_path.startswith("StressWatch/"):
        root_group = APP_ROOT_GROUP
        sources_phase = APP_TARGET_SOURCES_PHASE
        rel_inside_root = rel_path[len("StressWatch/"):]
    else:
        sys.exit(f"FATAL: unknown root for {rel_path}")

    parts = rel_inside_root.split("/")
    filename = parts[-1]

    build_id = oid("build", rel_path)
    ref_id = oid("ref", rel_path)

    if f"{ref_id} /* {filename} */ = {{" in src:
        print(f"  skip (already registered): {rel_path}")
        return src

    # 1) PBXBuildFile
    src = insert_before_end(
        src, "PBXBuildFile",
        f"\t\t{build_id} /* {filename} in Sources */ = {{isa = PBXBuildFile; "
        f"fileRef = {ref_id} /* {filename} */; }};\n",
    )

    # 2) PBXFileReference
    src = insert_before_end(
        src, "PBXFileReference",
        f"\t\t{ref_id} /* {filename} */ = {{isa = PBXFileReference; "
        f"lastKnownFileType = sourcecode.swift; path = {filename}; sourceTree = \"<group>\"; }};\n",
    )

    # 3) 中间分组
    parent = root_group
    key_so_far = "StressWatchTests" if root_group == TEST_ROOT_GROUP else "StressWatch"
    for part in parts[:-1]:
        key_so_far = f"{key_so_far}/{part}"
        parent, src = ensure_group(src, parent, part, key_so_far)

    # 4) 挂到父分组 children
    anchor = f"\t\t{parent} /* "
    pidx = src.find(anchor)
    if pidx == -1:
        sys.exit(f"FATAL: group {parent} not found")
    child_marker = "\t\t\tchildren = (\n"
    cidx = src.find(child_marker, pidx)
    src = src[:cidx + len(child_marker)] + f"\t\t\t\t{ref_id} /* {filename} */,\n" + src[cidx + len(child_marker):]

    # 5) 挂到 Sources build phase
    phase_anchor = f"\t\t{sources_phase} /* Sources */ = {{"
    phidx = src.find(phase_anchor)
    if phidx == -1:
        sys.exit(f"FATAL: sources phase {sources_phase} not found")
    files_marker = "\t\t\tfiles = (\n"
    fidx = src.find(files_marker, phidx)
    src = src[:fidx + len(files_marker)] + f"\t\t\t\t{build_id} /* {filename} in Sources */,\n" + src[fidx + len(files_marker):]

    print(f"  registered: {rel_path}")
    return src


def main() -> None:
    paths = sys.argv[1:]
    if not paths:
        print(__doc__)
        sys.exit(1)

    missing = [p for p in paths if not (ROOT / p).exists()]
    if missing:
        sys.exit(f"FATAL: file(s) not found: {missing}")

    backup = PBX.with_suffix(".pbxproj.bak")
    shutil.copy2(PBX, backup)
    print(f"backup -> {backup.name}")

    src = PBX.read_text(encoding="utf-8")
    for path in paths:
        src = register(src, path)
    PBX.write_text(src, encoding="utf-8")
    print("done")


if __name__ == "__main__":
    main()
