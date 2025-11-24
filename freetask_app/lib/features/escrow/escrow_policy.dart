bool canMutateEscrow(String? role) {
  return role?.toLowerCase() == 'admin';
}
