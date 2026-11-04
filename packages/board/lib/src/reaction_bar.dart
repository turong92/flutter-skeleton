import 'package:flutter/material.dart';

import 'models.dart';

/// How a reaction type is shown.
class BoardReactionStyle {
  const BoardReactionStyle({required this.label, required this.icon});

  final String label;
  final IconData icon;
}

/// The sample server's types. A project passes its own map for its own types;
/// a type missing from the map shows its code with a neutral icon.
const defaultBoardReactionStyles = <String, BoardReactionStyle>{
  'LIKE': BoardReactionStyle(label: 'Like', icon: Icons.thumb_up_outlined),
  'DISLIKE': BoardReactionStyle(
    label: 'Dislike',
    icon: Icons.thumb_down_outlined,
  ),
  'EMPATHY': BoardReactionStyle(label: 'Empathy', icon: Icons.favorite_border),
};

/// One button per reaction type. Every button has an outline (picked ones are
/// filled), so it reads as pressable at rest. [keyPrefix] makes the keys
/// `<prefix>-<TYPE>`.
class ReactionBar extends StatelessWidget {
  const ReactionBar({
    super.key,
    required this.keyPrefix,
    required this.types,
    required this.styles,
    required this.state,
    required this.onToggle,
  });

  final String keyPrefix;
  final List<String> types;
  final Map<String, BoardReactionStyle> styles;
  final ReactionState state;

  /// Null while a call is running: the buttons are disabled.
  final void Function(String type, {required bool picked})? onToggle;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [for (final type in types) _button(context, type)],
    );
  }

  Widget _button(BuildContext context, String type) {
    final style =
        styles[type] ??
        const BoardReactionStyle(label: '', icon: Icons.add_reaction_outlined);
    final name = style.label.isEmpty ? type : style.label;
    final count = state.counts[type] ?? 0;
    final picked = state.myReactions.contains(type);
    final text = count > 0 ? '$name $count' : name;
    final press = onToggle == null
        ? null
        : () => onToggle!(type, picked: picked);
    final compact = ButtonStyle(
      visualDensity: VisualDensity.compact,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
    return picked
        ? FilledButton.tonalIcon(
            key: ValueKey('$keyPrefix-$type'),
            style: compact,
            onPressed: press,
            icon: Icon(style.icon, size: 18),
            label: Text(text),
          )
        : OutlinedButton.icon(
            key: ValueKey('$keyPrefix-$type'),
            style: compact,
            onPressed: press,
            icon: Icon(style.icon, size: 18),
            label: Text(text),
          );
  }
}
