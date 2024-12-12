#!/bin/bash

# 检查是否以root权限运行
if [ "$EUID" -ne 0 ]; then
  echo "请以root权限运行此脚本。使用 sudo ./manage_grub.sh"
  exit 1
fi

echo "当前系统的 GRUB 启动项如下："
echo "-----------------------------------"

# 解析 GRUB 配置文件，提取菜单项
mapfile -t entries < <(grep "^menuentry '" /boot/grub2/grub.cfg | cut -d"'" -f2)

# 显示启动项列表
for i in "${!entries[@]}"; do
  echo "[$i] ${entries[$i]}"
done

echo "-----------------------------------"
echo "请输入要删除的启动项编号（或按 'q' 退出）："
read -r choice

# 检查用户是否选择退出
if [[ "$choice" == "q" || "$choice" == "Q" ]]; then
  echo "已退出。"
  exit 0
fi

# 验证输入是否为有效的数字
if ! [[ "$choice" =~ ^[0-9]+$ ]]; then
  echo "无效的输入。请输入有效的编号。"
  exit 1
fi

# 检查编号是否在范围内
if [ "$choice" -lt 0 ] || [ "$choice" -ge "${#entries[@]}" ]; then
  echo "编号超出范围。"
  exit 1
fi

selected_entry="${entries[$choice]}"
echo "您选择删除的启动项是：$selected_entry"

# 确认删除操作
echo "您确定要删除此启动项吗？（y/N）："
read -r confirm
if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
  echo "已取消删除操作。"
  exit 0
fi

# 判断启动项类型并执行相应的删除操作
if [[ "$selected_entry" == *"系统备份"* || "$selected_entry" == *"snapshot"* ]]; then
  echo "检测到该启动项可能对应一个系统快照。尝试删除相关快照。"

  # 检查是否安装了 Timeshift
  if command -v timeshift >/dev/null 2>&1; then
    echo "使用 Timeshift 删除快照。"
    # 列出所有快照
    timeshift --list

    echo "请输入要删除的快照名称（例如：2024-04-27_12-00）："
    read -r snapshot_name

    # 删除指定快照
    timeshift --delete --snapshot "$snapshot_name"

    if [ $? -eq 0 ]; then
      echo "快照 '$snapshot_name' 已成功删除。"
    else
      echo "删除快照失败，请检查输入是否正确或是否有足够权限。"
      exit 1
    fi
  else
    echo "系统快照工具（如 Timeshift）未安装。请手动删除相关快照。"
    exit 1
  fi
elif [[ "$selected_entry" == Rocky* ]]; then
  echo "检测到该启动项可能对应一个内核版本。尝试删除相关内核。"

  # 列出所有已安装的内核
  echo "已安装的内核版本："
  rpm -q kernel

  echo "请输入要删除的内核版本（例如：kernel-5.14.0-1.el8.x86_64）："
  read -r kernel_version

  # 确认内核版本是否存在
  if rpm -q "$kernel_version" >/dev/null 2>&1; then
    # 防止删除当前正在使用的内核
    current_kernel=$(uname -r)
    if [[ "$kernel_version" == *"$current_kernel"* ]]; then
      echo "无法删除当前正在使用的内核版本。请先切换到其他内核。"
      exit 1
    fi

    # 删除指定内核
    dnf remove -y "$kernel_version"

    if [ $? -eq 0 ]; then
      echo "内核 '$kernel_version' 已成功删除。"
    else
      echo "删除内核失败，请检查输入是否正确或是否有足够权限。"
      exit 1
    fi
  else
    echo "指定的内核版本未找到。"
    exit 1
  fi
else
  echo "无法识别启动项类型。请手动删除相关启动项。"
  exit 1
fi

# 更新 GRUB 配置
echo "正在更新 GRUB 配置..."
grub2-mkconfig -o /boot/grub2/grub.cfg

if [ $? -eq 0 ]; then
  echo "GRUB 配置已成功更新。"
else
  echo "更新 GRUB 配置失败。请检查错误信息。"
  exit 1
fi

echo "删除操作完成。请重启系统以应用更改。"
