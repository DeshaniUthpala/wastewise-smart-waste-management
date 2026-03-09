import 'package:flutter/material.dart';

class AppLocalizations {
  final Locale locale;

  AppLocalizations(this.locale);

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = AppLocalizationsDelegate();

  static final Map<String, Map<String, String>> _localizedValues = {
    'en': {
      'app_name': 'WasteWise',
      'login': 'Login',
      'signup': 'Sign Up',
      'email': 'Email',
      'password': 'Password',
      'welcome_back': 'Welcome Back!',
      'home': 'Home',
      'schedule': 'Schedule',
      'report': 'Report Issue',
      'profile': 'Profile',
      'request_pickup': 'Request Pickup',
      'notifications': 'Notifications',
      'rewards': 'Rewards',
      'map': 'Map View',
      'logout': 'Logout',
    },
    'si': {
      'app_name': 'වේස්ට්වයිස්',
      'login': 'ප්‍රවේශ වන්න',
      'signup': 'ලියාපදිංචි වන්න',
      'email': 'විද්‍යුත් තැපෑල',
      'password': 'මුරපදය',
      'welcome_back': 'නැවත පිළිගනිමු!',
      'home': 'මුල් පිටුව',
      'schedule': 'කාලසටහන',
      'report': 'ගැටළු වාර්තා කරන්න',
      'profile': 'පැතිකඩ',
    },
    'ta': {
      'app_name': 'வேஸ்ட்வைஸ்',
      'login': 'உள்நுழைய',
      'signup': 'பதிவு செய்க',
      'email': 'மின்னஞ்சல்',
      'password': 'கடவுச்சொல்',
      'welcome_back': 'மீண்டும் வரவேற்கிறோம்!',
      'home': 'முகப்பு',
      'schedule': 'அட்டவணை',
      'report': 'பிரச்சினை அறிக்கை',
      'profile': 'சுயவிவரம்',
    },
  };

  String translate(String key) {
    return _localizedValues[locale.languageCode]?[key] ?? key;
  }
}

class AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => ['en', 'si', 'ta'].contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return AppLocalizations(locale);
  }

  @override
  bool shouldReload(AppLocalizationsDelegate old) => false;
}
