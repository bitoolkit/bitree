import 'source.dart';

/// Converts ids written before source instances existed into the stable remote
/// identities used by the new source contract.
abstract final class LegacyRecordIds {
  static String deadlineRemoteId({
    required String id,
    required String? source,
    required Uri? url,
  }) {
    switch (source) {
      case 'lexue':
        if (id.startsWith('lexue-cmid-')) {
          return 'cm:${id.substring('lexue-cmid-'.length)}';
        }
        if (id.startsWith('lexue-')) {
          final moduleId = url?.queryParameters['id'];
          if (moduleId != null && moduleId.isNotEmpty) return 'cm:$moduleId';
          final event = id.substring('lexue-'.length).split('@').first;
          return 'event:$event';
        }
        return id;
      case 'eclass':
        return id.startsWith('eclass-')
            ? id.substring('eclass-'.length)
            : id;
      case 'mooc':
        return id;
      default:
        return id;
    }
  }

  static RecordOrigin? deadlineOrigin({
    required String id,
    required String? source,
    required Uri? url,
    required SourceResource resource,
  }) {
    if (source == null) return null;
    final definitionId = switch (source) {
      'lexue' => 'builtin.bit.lexue',
      'eclass' => 'builtin.bit.eclass',
      'mooc' => 'builtin.icourse163.mooc',
      _ => null,
    };
    if (definitionId == null) return null;
    return RecordOrigin(
      sourceInstanceId: 'instance:$definitionId',
      resource: resource,
      remoteId: deadlineRemoteId(id: id, source: source, url: url),
    );
  }

  static RecordOrigin physicsLabOrigin(String id) => RecordOrigin(
    sourceInstanceId: 'instance:builtin.bit.physics-lab',
    resource: SourceResource.deadline,
    remoteId: id,
  );

  static RecordOrigin schoolOrigin(String id) => RecordOrigin(
    sourceInstanceId: 'instance:builtin.bit.school',
    resource: SourceResource.timetable,
    remoteId: id,
  );

  static RecordOrigin schoolExamOrigin(String id) => RecordOrigin(
    sourceInstanceId: 'instance:builtin.bit.school',
    resource: SourceResource.exam,
    remoteId: id,
  );
}
