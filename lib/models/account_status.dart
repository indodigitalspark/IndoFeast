enum AccountStatus {
  pending('PENDING'),
  approved('APPROVED'),
  rejected('REJECTED'),
  suspended('SUSPENDED');

  const AccountStatus(this.value);

  final String value;

  String get label => value.replaceAll('_', ' ');

  static AccountStatus fromValue(String? value) {
    return AccountStatus.values.firstWhere(
      (status) => status.value == value,
      orElse: () => AccountStatus.pending,
    );
  }
}
