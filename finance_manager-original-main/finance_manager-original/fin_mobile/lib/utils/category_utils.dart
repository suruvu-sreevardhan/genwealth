const String uncategorizedKey = 'uncategorized';

const Map<String, String> _displayToCanonical = {
  'Food & Dining': 'food',
  'Shopping': 'shopping',
  'Transport': 'transport',
  'Entertainment': 'entertainment',
  'Bills & Utilities': 'utilities',
  'Health': 'healthcare',
  'Education': 'education',
  'Travel': 'transport',
  'Groceries': 'grocery',
  'Fuel': 'fuel',
  'Rent': 'rent',
  'EMI': 'emi',
  'Other': 'uncategorized',
};

const Map<String, String> _canonicalToDisplay = {
  'food': 'Food & Dining',
  'shopping': 'Shopping',
  'transport': 'Transport',
  'entertainment': 'Entertainment',
  'utilities': 'Bills & Utilities',
  'healthcare': 'Health',
  'education': 'Education',
  'grocery': 'Groceries',
  'fuel': 'Fuel',
  'rent': 'Rent',
  'emi': 'EMI',
  'salary': 'Salary',
  'income': 'Income',
  'uncategorized': 'Other',
};

const List<String> displayCategoriesForInput = [
  'Food & Dining',
  'Shopping',
  'Transport',
  'Entertainment',
  'Bills & Utilities',
  'Health',
  'Education',
  'Groceries',
  'Fuel',
  'Rent',
  'EMI',
  'Other',
];

const List<String> displayCategoriesForBudget = [
  'Food & Dining',
  'Shopping',
  'Transport',
  'Entertainment',
  'Bills & Utilities',
  'Health',
  'Education',
  'Groceries',
  'Fuel',
  'Rent',
  'EMI',
];

String toCanonicalCategory(String? value) {
  if (value == null || value.trim().isEmpty) return uncategorizedKey;
  final cleaned = value.trim().toLowerCase();

  for (final entry in _displayToCanonical.entries) {
    if (entry.key.toLowerCase() == cleaned) return entry.value;
  }

  if (_canonicalToDisplay.containsKey(cleaned)) return cleaned;

  if (cleaned == 'other' || cleaned == 'others') return uncategorizedKey;
  if (cleaned == 'groceries') return 'grocery';
  if (cleaned == 'travel') return 'transport';
  if (cleaned == 'health') return 'healthcare';
  if (cleaned == 'bills' ||
      cleaned == 'bill' ||
      cleaned == 'bills & utilities' ||
      cleaned == 'bills and utilities' ||
      cleaned == 'utility' ||
      cleaned == 'utilities bills' ||
      cleaned == 'bills_utilities' ||
      cleaned == 'bills-utilities') {
    return 'utilities';
  }

  return uncategorizedKey;
}

String toDisplayCategory(String? value) {
  final canonical = toCanonicalCategory(value);
  return _canonicalToDisplay[canonical] ?? 'Other';
}

String? toCanonicalOrNull(String? value) {
  if (value == null || value.trim().isEmpty) return null;
  return toCanonicalCategory(value);
}
