/// كتالوج معلومات المركبة: الماركات الشائعة وموديلاتها وسنوات الصنع.
///
/// يُستخدم لقسم «معلومات المركبة» في الشاشة الرئيسية، ويحمل القاعدة
/// الحكومية لقرار الدعم: سيارات سنة 2005 وما قبلها لا تدعم بروتوكول
/// OBD-II (الأوامر والفحوصات ممنوعة عليها)، وما فوق 2005 مدعوم.
class VehicleCatalog {
  VehicleCatalog._();

  /// أصغر سنة مدعومة للفحص — أقدم منها (≤ 2005) غير مدعوم.
  static const int minSupportedYear = 2006;

  /// هل سنة الصنع مدعومة للفحص عبر OBD-II؟
  static bool isYearSupported(int year) => year >= minSupportedYear;

  /// الماركات الشائعة.
  static const List<String> makes = <String>[
    'Toyota',
    'Nissan',
    'Hyundai',
    'Kia',
    'Honda',
    'Ford',
    'Chevrolet',
    'GMC',
    'Jeep',
    'Mazda',
    'Mitsubishi',
    'Mercedes-Benz',
    'BMW',
    'Lexus',
    'Infiniti',
    'Volkswagen',
    'Audi',
  ];

  /// موديلات كل ماركة (مفتاح الخريطة = الماركة من [makes]).
  static const Map<String, List<String>> modelsByMake = <String, List<String>>{
    'Toyota': <String>[
      'Corolla',
      'Camry',
      'Yaris',
      'Avalon',
      'Hilux',
      'Land Cruiser',
      'Prado',
      'RAV4',
      'Highlander',
      'FJ Cruiser',
      'C-HR',
      'Prius',
      'Supra',
    ],
    'Nissan': <String>[
      'Sunny',
      'Altima',
      'Maxima',
      'Sentra',
      'Micra',
      'Patrol',
      'Pathfinder',
      'X-Trail',
      'Murano',
      'Navara',
      '370Z',
      'Leaf',
    ],
    'Hyundai': <String>[
      'Accent',
      'Elantra',
      'Sonata',
      'Tucson',
      'Santa Fe',
      'Creta',
      'i10',
      'i20',
      'i30',
      'Veloster',
      'ix35',
    ],
    'Kia': <String>[
      'Picanto',
      'Rio',
      'Cerato',
      'Optima',
      'Cadenza',
      'Sportage',
      'Sorento',
      'Seltos',
      'Telluride',
      'Carnival',
    ],
    'Honda': <String>[
      'City',
      'Civic',
      'Accord',
      'Fit',
      'CR-V',
      'HR-V',
      'Pilot',
      'Odyssey',
    ],
    'Ford': <String>[
      'F-150',
      'Ranger',
      'Explorer',
      'Escape',
      'Edge',
      'Expedition',
      'Focus',
      'Fusion',
      'Mustang',
      'Transit',
    ],
    'Chevrolet': <String>[
      'Tahoe',
      'Suburban',
      'Silverado',
      'Camaro',
      'Corvette',
      'Malibu',
      'Cruze',
      'Equinox',
      'Traverse',
    ],
    'GMC': <String>[
      'Yukon',
      'Sierra',
      'Acadia',
      'Terrain',
    ],
    'Jeep': <String>[
      'Wrangler',
      'Grand Cherokee',
      'Cherokee',
      'Compass',
      'Renegade',
    ],
    'Mazda': <String>[
      'Mazda 2',
      'Mazda 3',
      'Mazda 6',
      'CX-3',
      'CX-5',
      'CX-9',
      'MX-5',
      'BT-50',
    ],
    'Mitsubishi': <String>[
      'Lancer',
      'Mirage',
      'Pajero',
      'Montero',
      'Outlander',
      'ASX',
      'Eclipse Cross',
      'L200',
    ],
    'Mercedes-Benz': <String>[
      'A-Class',
      'C-Class',
      'E-Class',
      'S-Class',
      'CLA',
      'GLC',
      'GLE',
      'G-Class',
      'Sprinter',
    ],
    'BMW': <String>[
      'Series 1',
      'Series 3',
      'Series 5',
      'Series 7',
      'X1',
      'X3',
      'X5',
      'X6',
      'X7',
      'M3',
      'M5',
    ],
    'Lexus': <String>[
      'ES',
      'GS',
      'IS',
      'LS',
      'NX',
      'RX',
      'GX',
      'LX',
      'UX',
    ],
    'Infiniti': <String>[
      'Q50',
      'Q60',
      'QX50',
      'QX56',
      'QX60',
      'QX80',
      'G37',
      'FX35',
    ],
    'Volkswagen': <String>[
      'Polo',
      'Golf',
      'Jetta',
      'Passat',
      'Beetle',
      'CC',
      'Tiguan',
      'Touareg',
      'Teramont',
    ],
    'Audi': <String>[
      'A3',
      'A4',
      'A6',
      'A8',
      'Q3',
      'Q5',
      'Q7',
      'TT',
    ],
  };

  /// موديلات الماركة المحددة.
  static List<String> modelsFor(String make) =>
      modelsByMake[make] ?? const <String>[];

  /// قائمة سنوات الصنع تنازلياً من السنة الحالية إلى أقدم سنة.
  static List<int> years({int? upTo, int from = 1960}) {
    final last = upTo ?? DateTime.now().year;
    return <int>[for (var y = last; y >= from; y--) y];
  }
}
