/// What the medicine physically is, as far as its printed name says.
enum MedicineForm { tablet, capsule, syrup, drops, injection, cream }

/// Read the form from the name as printed ("AZITHRAL 500 TAB", "CALPOL SYP").
///
/// Only for the picture beside the name while no strip photo exists: a wrong
/// guess costs a less helpful icon, never a dose. Tablet when nothing says
/// otherwise, because most prescriptions are tablets.
MedicineForm formOf(String name) {
  final words = name.toUpperCase().split(RegExp(r'[^A-Z]+'));
  bool any(Set<String> set) => words.any(set.contains);
  if (any(const {'SYP', 'SYRUP', 'SUSP', 'SUSPENSION', 'LIQUID'})) {
    return MedicineForm.syrup;
  }
  if (any(const {'DROP', 'DROPS', 'GTT', 'GTTS'})) return MedicineForm.drops;
  if (any(const {'INJ', 'INJECTION', 'VIAL'})) return MedicineForm.injection;
  if (any(const {'CREAM', 'OINT', 'OINTMENT', 'GEL', 'LOTION'})) {
    return MedicineForm.cream;
  }
  if (any(const {'CAP', 'CAPS', 'CAPSULE', 'CAPSULES'})) {
    return MedicineForm.capsule;
  }
  return MedicineForm.tablet;
}
