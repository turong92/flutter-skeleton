import 'package:flutter/material.dart';

/// A checkbox with the document's title, "required" or "optional", and a
/// button that opens the document. Shared by the sign-up list and the
/// re-consent screen.
class ConsentTile extends StatelessWidget {
  const ConsentTile({
    super.key,
    required this.checkKey,
    required this.viewKey,
    required this.title,
    required this.tag,
    required this.viewLabel,
    required this.checked,
    required this.onChanged,
    required this.onView,
  });

  final Key checkKey;
  final Key viewKey;
  final String title;
  final String tag;
  final String viewLabel;
  final bool checked;
  final ValueChanged<bool> onChanged;
  final VoidCallback onView;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Checkbox(
          key: checkKey,
          value: checked,
          onChanged: (value) => onChanged(value ?? false),
        ),
        Expanded(
          child: InkWell(
            onTap: () => onChanged(!checked),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title),
                  Text(tag, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
          ),
        ),
        OutlinedButton(key: viewKey, onPressed: onView, child: Text(viewLabel)),
      ],
    );
  }
}
