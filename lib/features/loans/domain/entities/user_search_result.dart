/// Resultado de búsqueda de usuario por teléfono.
class UserSearchResult {
  final bool    found;
  final String? id;
  final String? email;
  final String? fullName;
  final String? phoneNumber;

  const UserSearchResult({
    required this.found,
    this.id,
    this.email,
    this.fullName,
    this.phoneNumber,
  });

  factory UserSearchResult.notFound() =>
      const UserSearchResult(found: false);

  factory UserSearchResult.fromJson(Map<String, dynamic> j) =>
      UserSearchResult(
        found:       j['found'] as bool,
        id:          j['id'] as String?,
        email:       j['email'] as String?,
        fullName:    j['full_name'] as String?,
        phoneNumber: j['phone_number'] as String?,
      );

  String get displayName => fullName ?? email ?? phoneNumber ?? 'Usuario';

  String get initials {
    if (fullName != null && fullName!.isNotEmpty) {
      final parts = fullName!.trim().split(' ');
      if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
      return parts[0][0].toUpperCase();
    }
    return (email ?? '?')[0].toUpperCase();
  }
}
