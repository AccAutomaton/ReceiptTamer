// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ocr_text_block.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_OcrPoint _$OcrPointFromJson(Map<String, dynamic> json) =>
    _OcrPoint(x: (json['x'] as num).toInt(), y: (json['y'] as num).toInt());

Map<String, dynamic> _$OcrPointToJson(_OcrPoint instance) => <String, dynamic>{
  'x': instance.x,
  'y': instance.y,
};

_OcrTextBlock _$OcrTextBlockFromJson(Map<String, dynamic> json) =>
    _OcrTextBlock(
      text: json['text'] as String,
      boundingBox: (json['boundingBox'] as List<dynamic>)
          .map((e) => OcrPoint.fromJson(e as Map<String, dynamic>))
          .toList(),
      confidence: (json['confidence'] as num).toDouble(),
    );

Map<String, dynamic> _$OcrTextBlockToJson(_OcrTextBlock instance) =>
    <String, dynamic>{
      'text': instance.text,
      'boundingBox': instance.boundingBox,
      'confidence': instance.confidence,
    };

_OcrRawResult _$OcrRawResultFromJson(Map<String, dynamic> json) =>
    _OcrRawResult(
      success: json['success'] as bool,
      textBlocks: (json['textBlocks'] as List<dynamic>)
          .map((e) => OcrTextBlock.fromJson(e as Map<String, dynamic>))
          .toList(),
      errorMessage: json['errorMessage'] as String?,
      processingTimeMs: (json['processingTimeMs'] as num?)?.toInt(),
    );

Map<String, dynamic> _$OcrRawResultToJson(_OcrRawResult instance) =>
    <String, dynamic>{
      'success': instance.success,
      'textBlocks': instance.textBlocks,
      'errorMessage': instance.errorMessage,
      'processingTimeMs': instance.processingTimeMs,
    };
