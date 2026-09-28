import 'package:material_ui/material_ui.dart';

/// Reaching this control with a D-pad must not open the IME and trap navigation
/// before the user can reach voice search or phone pairing.
class TvSearchField extends StatelessWidget {
  const TvSearchField({
    super.key,
    required this.controller,
    required this.onChanged,
    required this.onSubmit,
    this.hint,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onSubmit;
  final String? hint;

  Future<void> _edit(BuildContext context) async {
    final submit = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('键盘输入'),
        content: SizedBox(
          width: 500,
          child: TextField(
            autofocus: true,
            controller: controller,
            textInputAction: TextInputAction.search,
            onChanged: onChanged,
            decoration: InputDecoration(hintText: hint ?? '搜索视频、UP 主或番剧'),
            onSubmitted: (_) => Navigator.pop(context, true),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('搜索'),
          ),
        ],
      ),
    );
    if (context.mounted && submit == true) onSubmit();
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
    valueListenable: controller,
    builder: (context, value, child) => TextButton.icon(
      onPressed: () => _edit(context),
      icon: const Icon(Icons.keyboard_outlined),
      label: Text(
        value.text.isEmpty ? '键盘输入' : value.text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 18),
      ),
    ),
  );
}
