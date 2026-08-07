/// Mirrors UTILITY_CATEGORY_LABELS in src/lib/utility-categories.ts.
const Map<String, String> utilityCategoryLabels = {
  'house_rent': 'House Rent',
  'electricity': 'Electricity',
  'gas': 'Gas',
  'servant': 'Servant Cost',
  'trash': 'Trash Cost',
  'internet': 'Internet Cost',
  'filter_kit': 'Filter Kit Cost',
  'other': 'Other',
};

String utilityCategoryLabel(String category) => utilityCategoryLabels[category] ?? category;
