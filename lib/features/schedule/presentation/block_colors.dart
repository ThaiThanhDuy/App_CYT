import 'package:flutter/material.dart';

import '../domain/task_block.dart';

/// Màu chọn được cho block (ARGB). Không chọn = xám nhạt mặc định.
const blockPalette = <int>[
  0xFFFF5A5A, // đỏ
  0xFFFF9F43, // cam
  0xFFFFC400, // vàng
  0xFF2BFF6B, // xanh lá
  0xFF2ED3E6, // xanh ngọc
  0xFF4D8DFF, // xanh dương
  0xFFA77BFF, // tím
  0xFFFF6FB5, // hồng
];

/// Xám nhạt mặc định (đậm hơn chút ở nền sáng cho dễ đọc).
Color defaultBlockColor(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
    ? const Color(0xFFBDBDBD)
    : const Color(0xFF8A8A8A);

/// Màu hiển thị của [block].
Color blockColorOf(BuildContext context, TaskBlock block) =>
    block.color != null ? Color(block.color!) : defaultBlockColor(context);
