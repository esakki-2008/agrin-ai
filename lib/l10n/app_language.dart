class AppLanguage {
  final String code;
  final String name;
  final String nativeName;
  final String speechLocale;
  final String aiName;

  const AppLanguage({required this.code, required this.name, required this.nativeName, required this.speechLocale, required this.aiName});
}

const supportedLanguages = <AppLanguage>[
  AppLanguage(code:'en',name:'English',nativeName:'English',speechLocale:'en-IN',aiName:'English'),
  AppLanguage(code:'hi',name:'Hindi',nativeName:'हिन्दी',speechLocale:'hi-IN',aiName:'Hindi'),
  AppLanguage(code:'mr',name:'Marathi',nativeName:'मराठी',speechLocale:'mr-IN',aiName:'Marathi'),
  AppLanguage(code:'bn',name:'Bengali',nativeName:'বাংলা',speechLocale:'bn-IN',aiName:'Bengali'),
  AppLanguage(code:'te',name:'Telugu',nativeName:'తెలుగు',speechLocale:'te-IN',aiName:'Telugu'),
  AppLanguage(code:'ta',name:'Tamil',nativeName:'தமிழ்',speechLocale:'ta-IN',aiName:'Tamil'),
  AppLanguage(code:'gu',name:'Gujarati',nativeName:'ગુજરાતી',speechLocale:'gu-IN',aiName:'Gujarati'),
  AppLanguage(code:'kn',name:'Kannada',nativeName:'ಕನ್ನಡ',speechLocale:'kn-IN',aiName:'Kannada'),
  AppLanguage(code:'ml',name:'Malayalam',nativeName:'മലയാളം',speechLocale:'ml-IN',aiName:'Malayalam'),
  AppLanguage(code:'pa',name:'Punjabi',nativeName:'ਪੰਜਾਬੀ',speechLocale:'pa-IN',aiName:'Punjabi'),
  AppLanguage(code:'as',name:'Assamese',nativeName:'অসমীয়া',speechLocale:'as-IN',aiName:'Assamese'),
  AppLanguage(code:'or',name:'Odia',nativeName:'ଓଡ଼ିଆ',speechLocale:'or-IN',aiName:'Odia'),
  AppLanguage(code:'ur',name:'Urdu',nativeName:'اردو',speechLocale:'ur-IN',aiName:'Urdu'),
  AppLanguage(code:'sa',name:'Sanskrit',nativeName:'संस्कृतम्',speechLocale:'sa-IN',aiName:'Sanskrit'),
  AppLanguage(code:'mai',name:'Maithili',nativeName:'मैथिली',speechLocale:'mai-IN',aiName:'Maithili'),
  AppLanguage(code:'ne',name:'Nepali',nativeName:'नेपाली',speechLocale:'ne-IN',aiName:'Nepali'),
  AppLanguage(code:'kok',name:'Konkani',nativeName:'कोंकणी',speechLocale:'kok-IN',aiName:'Konkani'),
  AppLanguage(code:'doi',name:'Dogri',nativeName:'डोगरी',speechLocale:'doi-IN',aiName:'Dogri'),
  AppLanguage(code:'ks',name:'Kashmiri',nativeName:'कॉशुर',speechLocale:'ks-IN',aiName:'Kashmiri'),
  AppLanguage(code:'mni',name:'Manipuri',nativeName:'মৈতৈলোন্',speechLocale:'mni-IN',aiName:'Manipuri'),
  AppLanguage(code:'brx',name:'Bodo',nativeName:'बड़ो',speechLocale:'brx-IN',aiName:'Bodo'),
  AppLanguage(code:'sat',name:'Santali',nativeName:'ᱥᱟᱱᱛᱟᱲᱤ',speechLocale:'sat-IN',aiName:'Santali'),
  AppLanguage(code:'sd',name:'Sindhi',nativeName:'سنڌي',speechLocale:'sd-IN',aiName:'Sindhi'),
];

AppLanguage languageForCode(String code) => supportedLanguages.firstWhere(
  (language) => language.code == code,
  orElse: () => supportedLanguages.first,
);