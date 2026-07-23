import 'package:flutter/material.dart';

import '../../data/models/llm_backend.dart';
import '../../data/services/ai_use_disclosure_service.dart';
import '../widgets/common/glass_alert_dialog.dart';

enum AiAnalysisChoice { manual, local, cloud }

enum CloudUploadContent { orderImage, orderText, invoiceImage, invoiceText }

Future<AiAnalysisChoice?> showAiAnalysisChoiceDialog(BuildContext context) {
  return showDialog<AiAnalysisChoice>(
    context: context,
    builder: (dialogContext) => GlassAlertDialog(
      title: const Text('选择录入方式'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _AiChoiceTile(
            icon: Icons.edit_note,
            title: '纯手工',
            description: '立即开始 · 数据不离开设备 · 无模型调用费用',
            onTap: () => Navigator.pop(dialogContext, AiAnalysisChoice.manual),
          ),
          _AiChoiceTile(
            icon: Icons.phone_android,
            title: '本地模型',
            description: '首次下载和加载较慢 · 全程本机处理 · 无云端调用费用',
            onTap: () => Navigator.pop(dialogContext, AiAnalysisChoice.local),
          ),
          _AiChoiceTile(
            icon: Icons.cloud_outlined,
            title: '云端模型',
            description: '通常更快 · 内容发送至指定模型供应商 · 可能产生服务商费用',
            onTap: () => Navigator.pop(dialogContext, AiAnalysisChoice.cloud),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('返回'),
        ),
      ],
    ),
  );
}

Future<bool> confirmCloudUploadIfNeeded(
  BuildContext context, {
  required LlmBackendConfig config,
  required CloudUploadContent content,
}) async {
  if (config.backendType != LlmBackendType.openAiCompatible) return true;

  final endpoint = Uri.tryParse(config.cloud.endpoint.trim());
  final host = endpoint?.host.trim() ?? '';
  if (host.isEmpty) {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => GlassAlertDialog(
        title: const Text('云端地址无效'),
        content: const Text('当前配置无法识别目标域名。请检查云端模型地址后再试。'),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
    return false;
  }

  final disclosureService = AiUseDisclosureService();
  if (await disclosureService.hasCloudConsent(host)) return true;
  if (!context.mounted) return false;

  final allowed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => GlassAlertDialog(
      title: const Text('首次云端上传确认'),
      content: Text(
        '本次会把${_contentDescription(content)}发送到：\n\n'
        '$host\n\n'
        '${_privacyDescription(content)}速度和费用由该服务商及所选模型决定。',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text('确认并上传'),
        ),
      ],
    ),
  );
  if (allowed != true) return false;

  await disclosureService.rememberCloudConsent(host);
  return true;
}

String _contentDescription(CloudUploadContent content) {
  return switch (content) {
    CloudUploadContent.orderImage => '订单图片',
    CloudUploadContent.orderText => '从订单图片识别出的文字',
    CloudUploadContent.invoiceImage => '发票图片',
    CloudUploadContent.invoiceText => '从发票附件提取或识别出的文字',
  };
}

String _privacyDescription(CloudUploadContent content) {
  return switch (content) {
    CloudUploadContent.orderImage ||
    CloudUploadContent.invoiceImage => '图片可能包含姓名、地址、单号、商家和金额等信息。',
    CloudUploadContent.orderText ||
    CloudUploadContent.invoiceText => '发送内容可能包含单号、商家、日期和金额等信息。',
  };
}

class _AiChoiceTile extends StatelessWidget {
  const _AiChoiceTile({
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      minVerticalPadding: 10,
      leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
      title: Text(title),
      subtitle: Text(description),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
