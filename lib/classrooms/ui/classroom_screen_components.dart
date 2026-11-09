part of 'classroom_screen.dart';

class _QueryFields extends StatelessWidget {
  const _QueryFields({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final scale = MediaQuery.textScalerOf(context).scale(1);
      final minimumWidth = MediaQuery.textScalerOf(context).scale(13) * 8 + 36;
      final columns = constraints.maxWidth >= 720 * scale
          ? 4
          : constraints.maxWidth >= minimumWidth * 2 + 8
          ? 2
          : 1;
      final width = (constraints.maxWidth - 8 * (columns - 1)) / columns;
      return Wrap(
        spacing: 8,
        runSpacing: 12,
        children: [
          for (final child in children) SizedBox(width: width, child: child),
        ],
      );
    },
  );
}

class _QueryState extends StatelessWidget {
  const _QueryState({
    required this.message,
    required this.action,
    required this.onPressed,
  });

  final String message;
  final String action;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(message),
        const SizedBox(height: 8),
        TextButton(onPressed: onPressed, child: Text(action)),
      ],
    ),
  );
}

Future<void> _showRoom(
  BuildContext context,
  TimetableController timetable,
  SchoolBuilding building,
  ClassroomOccupancy room,
  DateTime date,
) => showAppSheet<void>(
  context: context,
  builder: (sheetContext) {
    final l10n = sheetContext.l10n;
    return SheetLayout(
      header: SheetHeader(
        title: Text('${building.name} ${room.name}'),
        actions: const [SheetCloseButton()],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '${dateText(date)} '
            '${localizedShortWeekday(l10n, date.weekday)}',
            style: Theme.of(sheetContext).textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpacing.md),
          for (final block in room.periods)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(block.period.localizedTime(l10n)),
              subtitle: Text(block.period.localizedSection(l10n)),
              trailing: Text(
                block.busy ? l10n.busyStatus : l10n.freeStatus,
                style: TextStyle(
                  color: block.busy
                      ? Theme.of(sheetContext).colorScheme.onSurfaceVariant
                      : Theme.of(sheetContext).colorScheme.primary,
                ),
              ),
            ),
        ],
      ),
      actions: WencuiPlace.parse('${building.name} ${room.name}') == null
          ? null
          : SheetActionBar.actions(
              children: [
                TextButton.icon(
                  onPressed: () {
                    Navigator.pop(sheetContext);
                    Navigator.of(context).push<void>(
                      MaterialPageRoute(
                        builder: (_) => WencuiMapScreen(
                          timetable: timetable,
                          initialRoom: '${building.name} ${room.name}',
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.map_outlined, size: 18),
                  label: Text(l10n.wencuiMap),
                ),
              ],
            ),
    );
  },
);
