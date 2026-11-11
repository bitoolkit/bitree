class AgendaColor {
  const AgendaColor(this.value) : id = null;

  const AgendaColor._(this.id, this.value);

  final String? id;
  final int value;

  static const blue = AgendaColor._('blue', 0xFF1A5998);
  static const coral = AgendaColor._('coral', 0xFF8D3C18);
  static const violet = AgendaColor._('violet', 0xFF6C4289);
  static const green = AgendaColor._('green', 0xFF026947);
  static const amber = AgendaColor._('amber', 0xFF735102);
  static const teal = AgendaColor._('teal', 0xFF146C60);
  static const rose = AgendaColor._('rose', 0xFF8F3854);
  static const slate = AgendaColor._('slate', 0xFF4F5D6E);

  static const presets = [blue, coral, violet, green, amber, teal, rose, slate];

  static AgendaColor? presetNamed(String? id) =>
      presets.where((color) => color.id == id).firstOrNull;

  static AgendaColor? presetByValue(int value) =>
      presets.where((color) => color.value == value).firstOrNull;

  @override
  bool operator ==(Object other) =>
      other is AgendaColor && other.id == id && other.value == value;

  @override
  int get hashCode => Object.hash(id, value);
}
