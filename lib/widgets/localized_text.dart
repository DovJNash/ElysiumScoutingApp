import 'package:flutter/material.dart' as material;

import '../services/locale_service.dart';

class Text extends material.StatelessWidget {
  final String data;
  final material.TextStyle? style;
  final material.TextAlign? textAlign;
  final material.TextOverflow? overflow;
  final int? maxLines;
  final bool? softWrap;

  const Text(
    this.data, {
    super.key,
    this.style,
    this.textAlign,
    this.overflow,
    this.maxLines,
    this.softWrap,
  });

  @override
  material.Widget build(material.BuildContext context) => material.Text(
        LocaleService.instance.text(data),
        style: style,
        textAlign: textAlign,
        overflow: overflow,
        maxLines: maxLines,
        softWrap: softWrap,
      );
}
