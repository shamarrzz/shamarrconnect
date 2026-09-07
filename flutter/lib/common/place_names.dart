/// OS hostname / factory model, not a place name the user chose.
bool looksLikeFactoryName(String name, {String hostname = ''}) {
  final n = name.trim();
  if (n.isEmpty) return true;
  if (hostname.isNotEmpty && n.toLowerCase() == hostname.toLowerCase()) {
    return true;
  }
  final u = n.toUpperCase();
  const prefixes = [
    'DESKTOP-',
    'LAPTOP-',
    'WIN-',
    'MACBOOK',
    'IMAC',
    'IPHONE',
    'IPAD',
    'PIXEL',
    'SM-',
    'GALAXY',
    'SAMSUNG-',
    'ANDROID-',
    'POCO',
    'REDMI',
    'GOOGLE-SDK',
    'SDK_GPHONE',
    'EMULATOR',
  ];
  if (prefixes.any(u.startsWith)) return true;
  if (u.contains('-SM-')) return true;
  if (n.contains('.') && !n.contains(' ')) return true;
  if (RegExp(r'^[A-Z0-9_-]{8,}$').hasMatch(u) && !n.contains(' ')) {
    return true;
  }
  return false;
}
