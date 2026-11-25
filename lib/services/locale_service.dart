import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocaleService extends ChangeNotifier {
  LocaleService._();
  static final instance = LocaleService._();

  static const String _prefsKey = 'elysium_locale';
  Locale _locale = const Locale('he');

  Locale get locale => _locale;
  bool get isHebrew => _locale.languageCode == 'he';

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_prefsKey);
    _locale = Locale(code == 'en' ? 'en' : 'he');
  }

  Future<void> setLocale(Locale locale) async {
    if (locale.languageCode != 'en' && locale.languageCode != 'he') return;
    final nextLocale = Locale(locale.languageCode);
    if (_locale == nextLocale) return;
    _locale = nextLocale;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, locale.languageCode);
  }

  String text(String value) {
    if (!_isHebrew) return value;
    return _he[value] ?? _translateDynamic(value) ?? value;
  }

  bool get _isHebrew => _locale.languageCode == 'he';

  static const Map<String, String> _he = {
    'SCOUTING SYSTEM': 'מערכת סקאוטינג',
    'LOG IN': 'כניסה',
    'SIGN UP': 'הרשמה',
    'Choose your team': 'בחירת הקבוצה שלך',
    'Israeli FRC teams — 2027 season': 'קבוצות FRC בישראל — עונת 2027',
    'Loading teams...': 'טוען קבוצות...',
    'No teams found. Try again later.': 'לא נמצאו קבוצות. נסו שוב מאוחר יותר.',
    'Team number': 'מספר קבוצה',
    'Team name': 'שם הקבוצה',
    'Team name (optional)': 'שם הקבוצה (לא חובה)',
    'Enter a valid team number.': 'יש להזין מספר קבוצה תקין.',
    'Continue with this team': 'המשך עם הקבוצה הזו',
    'Back to team list': 'חזרה לרשימת הקבוצות',
    'Can’t load or find your team? Enter it manually':
        'הקבוצה לא נטענת או לא נמצאה? הזן אותה ידנית',
    'e.g. 1937': 'לדוגמה, 1937',
    'e.g. Elysium': 'לדוגמה, אליסיום',
    'Team name could not be found. Please enter it manually.':
        'לא נמצא שם הקבוצה. יש להזין אותו ידנית.',
    'Could not look up the team name. Please enter it manually.':
        'לא ניתן לאתר את שם הקבוצה. יש להזין אותו ידנית.',
    'Looking up team...': 'מחפש את הקבוצה...',
    'Choose a 2027 Israel competition': 'בחירת תחרות בישראל לשנת 2027',
    'Refresh competitions': 'רענון תחרויות',
    'No 2027 Israel competitions found.':
        'לא נמצאו תחרויות בישראל לשנת 2027.',
    'Could not load the 2027 Israeli team list. Check the TBA API key and internet connection.':
        'טעינת רשימת הקבוצות בישראל נכשלה. יש לבדוק חיבור לאינטרנט ואת מפתח TBA.',
    'Access your scouting, strategy or lead console':
        'גישה למערכת הסקאוטינג, האסטרטגיה או הניהול',
    'Create an account and choose your team role':
        'יצירת חשבון ובחירת תפקיד בקבוצה',
    'What is your role?': 'מה התפקיד שלך?',
    'Scouter': 'סקאוטר',
    'Strategy': 'אסטרטגיה',
    'Leader': 'מנהל',
    'Live match data collection': 'איסוף נתונים בזמן משחק',
    'Super scouting & analytics (access code)':
        'סקאוטינג מתקדם וניתוח נתונים (נדרש קוד)',
    'Scout rankings & moderation (access code)':
        'דירוג סקאוטרים וניהול טפסים (נדרש קוד)',
    'Back': 'חזרה',
    'Create Scouter Account': 'יצירת חשבון סקאוטר',
    'Create Strategy Account': 'יצירת חשבון אסטרטגיה',
    'Create Leader Account': 'יצירת חשבון מנהל',
    'Welcome Back': 'ברוך שובך',
    'Role: Scouter': 'תפקיד: סקאוטר',
    'Role: Strategy': 'תפקיד: אסטרטגיה',
    'Role: Leader': 'תפקיד: מנהל',
    'Enter your name and password to continue':
        'יש להזין שם וסיסמה כדי להמשיך',
    'Name': 'שם',
    'Password': 'סיסמה',
    'Change': 'שינוי',
    'Scouter access code': 'קוד גישה לסקאוטר',
    'Strategy access code': 'קוד גישה לאסטרטגיה',
    'Leader access code': 'קוד גישה למנהל',
    'Ask your team lead for the code for this team':
        'יש לבקש ממוביל הקבוצה את הקוד הייעודי לקבוצה',
    'Please enter both name and password.': 'יש להזין שם וסיסמה.',
    'Invalid name or password.': 'השם או הסיסמה שגויים.',
    'Name and password cannot be empty.': 'שם וסיסמה אינם יכולים להיות ריקים.',
    'Sign up failed. Please try again.': 'ההרשמה נכשלה. יש לנסות שוב.',
    'No internet connection. Logging in / signing up needs internet.':
        'אין חיבור לאינטרנט. כניסה והרשמה דורשות חיבור.',
    'Complete Sign Up': 'סיום הרשמה',
    'Log In': 'כניסה',
    'The app could not start': 'היישום לא הצליח להיפתח',
    'Check lib/config/supabase_config.dart (URL and publishable key).':
        'יש לבדוק את כתובת ה־URL והמפתח בקובץ הגדרות Supabase.',
    'Enter a valid match number first.': 'יש להזין תחילה מספר משחק תקין.',
    'Choose another team': 'בחירת קבוצה אחרת',
    'e.g. 2025isde1': 'לדוגמה, 2025isde1',
    'Competition ID': 'מזהה תחרות',
    'Competition name': 'שם התחרות',
    'Existing team numbers': 'מספרי קבוצות קיימות',
    'Cancel': 'ביטול',
    'Create': 'יצירה',
    'Create competition': 'יצירת תחרות',
    'Event': 'תחרות',
    'Rankings': 'דירוגים',
    'Forms': 'טפסים',
    'Data': 'נתונים',
    'Overall': 'דירוג כללי',
    'Schedule': 'לוח משחקים',
    'Pit': 'סקאוטינג פיט',
    'Super Scouting': 'סקאוטינג מתקדם',
    'Match Scouting': 'סקאוטינג משחק',
    'My Submissions': 'הטפסים שלי',
    'My Reports': 'הדוחות שלי',
    'Log Out': 'יציאה',
    'Competition': 'תחרות',
    'Select Competition': 'בחירת תחרות',
    'Select Competition for Super Scouting': 'בחירת תחרות לסקאוטינג מתקדם',
    'Select Competition for Pit Scouting': 'בחירת תחרות לסקאוטינג פיט',
    'Search team number or name': 'חיפוש לפי מספר קבוצה או שם',
    'Competitions': 'תחרויות',
    'Next': 'הבא',
    'Submit': 'שליחה',
    'Submitting...': 'שולח...',
    'Change Team': 'החלפת קבוצה',
    'Match Setup': 'הגדרת משחק',
    'Autonomous': 'אוטונומי',
    'Teleop & Zones': 'טלאופ ואזורים',
    'Left': 'שמאל',
    'Center': 'מרכז',
    'Right': 'ימין',
    'No Show': 'לא הופיע',
    'Left Lane': 'מסלול שמאלי',
    'Center Lane': 'מסלול מרכזי',
    'Right Lane': 'מסלול ימני',
    'Did Not Exit': 'לא יצא',
    'Starting Position': 'עמדת התחלה',
    'Exit Path': 'מסלול יציאה',
    'AUTONOMOUS PERIOD': 'שלב אוטונומי',
    'Auto Game Pieces Scored': 'משחקים שנצברו באוטונומי',
    'How Many Fuels Passed to Alliance Zone':
        'כמה דלקים הרובוט העביר לאזור הברית',
    'Teleop Game Pieces Scored': 'משחקים שנצברו בטלאופ',
    'Zone Time (seconds)': 'זמן באזור (שניות)',
    'Alliance Zone': 'אזור הברית',
    'Neutral Zone': 'אזור ניטרלי',
    'Opponent Zone': 'אזור היריב',
    'Ratings & Notes': 'דירוגים והערות',
    'Defense played': 'משחק הגנה',
    'Resilience vs defense': 'עמידות מול הגנה',
    'Driver skill': 'מיומנות נהג',
    'Match Number': 'מספר משחק',
    'General Notes': 'הערות כלליות',
    'Mechanical issues, penalties, endgame, cycle notes...':
        'תקלות מכניות, עבירות, סוף משחק והערות על מחזורים...',
    'Running': 'פועל',
    'Track': 'מדוד',
    'Average': 'ממוצע',
    'Auto vs Teleop Scoring (top teams)': 'ניקוד אוטונומי וטלאופ (קבוצות מובילות)',
    'Overall Rating (top 10)': 'דירוג כללי (10 המובילות)',
    'Scoring & Alliance-Zone Fuel Telemetry (averages)':
        'נתוני ניקוד והעברת דלק לאזור הברית (ממוצעים)',
    'Shooting rate (BPS)': 'קצב ירי (כדורים לשנייה)',
    'Shooting mechanics': 'מנגנון ירי',
    'Missed shots': 'החטאות',
    'Fuel passing to alliance zone': 'העברת דלק לאזור הברית',
    'Driver skills': 'מיומנות נהג',
    'Driving technique': 'טכניקת נהיגה',
    'Defensive style': 'סגנון הגנה',
    'Autonomous Operation & Routine': 'פעולה ושגרה אוטונומית',
    'Estimated Shooting Rate (Balls Per Second)': 'קצב ירי משוער (כדורים לשנייה)',
    'Shooting Mechanics & Capabilities': 'מנגנון ירי ויכולות',
    'Percentage of Missed Shots (%)': 'אחוז החטאות (%)',
    'Fuel Passing / Alliance Zone Mechanism': 'העברת דלק / מנגנון אזור הברית',
    'Robot Storage Capacity': 'קיבולת אחסון הרובוט',
    'Robot Limitations / Constraints': 'מגבלות הרובוט',
    'Driver Skill Assessment (Strengths & Weaknesses)': 'הערכת מיומנות הנהג (חוזקות וחולשות)',
    'Penalties & Foul Tendencies': 'עבירות ונטייה לעבירות',
    'Speed When Crossing the "Bump"': 'מהירות במעבר מעל המכשול',
    'Preferred Driving Techniques / Methods': 'טכניקות ושיטות נהיגה מועדפות',
    'Defensive Style': 'סגנון הגנה',
    'Paths, game pieces scored, reliability, disruption...':
        'מסלולים, ניקוד, אמינות והשפעה על היריב...',
    'e.g., 2.5 BPS burst / 1.8 BPS sustained':
        'לדוגמה: 2.5 כדורים לשנייה בפרץ / 1.8 באופן רציף',
    'Fixed angle, turret, adjustable hood, range limits...':
        'זווית קבועה, צריח, כוונון זווית וטווח...',
    'e.g., ~15% overall, struggles from far distance':
        'לדוגמה: כ-15% החטאות, קושי בירי מרחוק',
    'Over-bumper vs under-bumper, speed of pickup...':
        'איסוף מעל או מתחת למכשול, מהירות איסוף...',
    'e.g., Holds up to 5 game pieces comfortably':
        'לדוגמה: יכול להכיל בנוחות עד 5 כדורי משחק',
    'Brownouts, tipping risk, slow recovery, fragile parts...':
        'נפילות מתח, סכנת התהפכות, התאוששות איטית וחלקים עדינים...',
    'Spatial awareness, evading defense, alignment precision...':
        'מודעות מרחבית, התחמקות מהגנה ודיוק יישור...',
    'Pinning, frame perimeter, contact fouls...':
        'הצמדה, חריגה ממסגרת הרובוט ועבירות מגע...',
    'Full speed, slows down, or avoids the bump...':
        'מהירות מלאה, האטה או הימנעות מהמכשול...',
    'Field-centric swerve, herding, cycling lanes...':
        'נהיגת סוורב ביחס למגרש, הובלת כדורים ומסלולי מחזור...',
    'Zone denial, lane blocking, pinning timing, or pure scorer...':
        'חסימת אזורים ומסלולים, תזמון הצמדה או התמקדות בניקוד...',
    'No scouting sessions for this event yet.':
        'עדיין אין נתוני סקאוטינג לתחרות זו.',
    'No cross-competition team data yet.':
        'עדיין אין נתוני קבוצות מכל התחרויות.',
    'No forms for this event.': 'אין טפסים לתחרות זו.',
    'No scouted matches for this competition yet.':
        'עדיין לא נסרקו משחקים בתחרות זו.',
    'No Super Scouting reports for this competition yet.':
        'אין עדיין דוחות סקאוטינג מתקדם לתחרות זו.',
    'Scout Performance Rankings': 'דירוג ביצועי סקאוטרים',
    'Overall Team Rankings': 'דירוג קבוצות כללי',
    'All Submitted Forms': 'כל הטפסים שנשלחו',
    'Delete form': 'מחיקת טופס',
    'Delete this form?': 'למחוק את הטופס?',
    'It will be removed for everyone.': 'הטופס יימחק עבור כולם.',
    'Close': 'סגירה',
    'Retry now': 'ניסיון נוסף',
    'Sync problem': 'בעיה בסנכרון',
    'Team': 'קבוצה',
    'Auto Shot': 'קליעות אוטונומיות',
    'Auto Fuel': 'דלק אוטונומי',
    'Tele Shot': 'קליעות טלאופ',
    'Tele Fuel': 'דלק טלאופ',
    'Est BPS': 'קצב ירי משוער',
    'Miss %': 'אחוז החטאות',
    'Alliance': 'ברית',
    'Neutral': 'ניטרלי',
    'Opponent': 'יריב',
    'Doing Def': 'הגנה',
    'Stand Def': 'עמידות בהגנה',
    'Driver': 'נהג',
    'Capacity': 'קיבולת',
    'Bump': 'מעבר מכשול',
    'Defense': 'הגנה',
    'Limitations': 'מגבלות',
    'Penalties': 'עבירות',
    'Load': 'טעינה',
    'No schedule loaded': 'לוח המשחקים לא נטען',
    'Pit Scouting': 'סקאוטינג פיט',
    'Autonomous types': 'סוגי אוטונומי',
    'What the team does well': 'החוזקות של הקבוצה',
    'What is difficult for the team': 'האתגרים של הקבוצה',
    'How the team plays defense': 'סגנון ההגנה של הקבוצה',
    'How is the team different': 'במה הקבוצה מיוחדת',
    'Other notes': 'הערות נוספות',
    'Submit Pit Scouting': 'שליחת סקאוטינג פיט',
    'Submit Super Scouting': 'שליחת סקאוטינג מתקדם',
    'Select another team': 'בחירת קבוצה אחרת',
    'Replace': 'החלפה',
    'Already submitted': 'כבר נשלח',
    'Report already exists': 'הדוח כבר קיים',
    'Form time': 'משך מילוי הטופס',
    'Synced': 'מסונכרן',
    'Waiting for internet': 'ממתין לחיבור לאינטרנט',
    'Match Schedule': 'לוח משחקים',
    'Qualification': 'מוקדמות',
    'Red': 'אדום',
    'Blue': 'כחול',
    'Matches': 'משחקים',
    'sessions': 'מפגשים',
    'Accuracy': 'דיוק',
    'Avg': 'ממוצע',
    'registered teams': 'קבוצות רשומות',
    'Start position': 'עמדת התחלה',
    'Exit path': 'מסלול יציאה',
    'Notes': 'הערות',
    'No team found. Type the team number to add it.':
        'הקבוצה לא נמצאה. אפשר לחפש לפי מספר קבוצה.',
    'Scout it anyway': 'סקאוטינג בכל זאת',
    'No team match': 'לא נמצאה קבוצה',
    'TBA event key': 'מזהה אירוע TBA',
    'No team found.': 'לא נמצאה קבוצה.',
    'Save on this device. It will upload when internet returns.':
        'נשמר במכשיר ויסונכרן כשהחיבור יחזור.',
    'Language': 'שפה',
  };

  String? _translateDynamic(String value) {
    final unlisted =
        RegExp(r'^Team (\d+) \(not in list\)$').firstMatch(value);
    if (unlisted != null) {
      return 'קבוצה ${unlisted.group(1)} (לא ברשימה)';
    }
    final pit = RegExp(r'^Pit Scouting • Team (\d+)$').firstMatch(value);
    if (pit != null) return 'סקאוטינג פיט • קבוצה ${pit.group(1)}';
    final qualification = RegExp(r'^Qualification (\d+)$').firstMatch(value);
    if (qualification != null) {
      return 'מוקדמות ${qualification.group(1)}';
    }
    final teamsRegistered =
        RegExp(r'^(\d+) registered teams$').firstMatch(value);
    if (teamsRegistered != null) {
      return '${teamsRegistered.group(1)} קבוצות רשומות';
    }
    final formStats = RegExp(
      r'^Sessions (\d+) • Accuracy ([^•]+) • Avg (\d+)s(.*)$',
    ).firstMatch(value);
    if (formStats != null) {
      return 'מפגשים ${formStats.group(1)} • דיוק ${formStats.group(2)} • '
          'ממוצע ${formStats.group(3)} שנ׳${formStats.group(4)}';
    }
    final allianceScores =
        RegExp(r'^Red: (.*)  •  Blue: (.*)$').firstMatch(value);
    if (allianceScores != null) {
      return 'אדום: ${allianceScores.group(1)}  •  כחול: ${allianceScores.group(2)}';
    }
    final rating = RegExp(r'^(.+) pts$').firstMatch(value);
    if (rating != null) return '${rating.group(1)} נק׳';
    final createAccount =
        RegExp(r'^Create (Scouter|Strategy|Leader) Account$').firstMatch(value);
    if (createAccount != null) {
      return 'יצירת חשבון ${_he[createAccount.group(1)]}';
    }
    final role = RegExp(r'^Role: (Scouter|Strategy|Leader)$').firstMatch(value);
    if (role != null) return 'תפקיד: ${_he[role.group(1)]}';
    final accessCode =
        RegExp(r'^(Scouter|Strategy|Leader) access code$').firstMatch(value);
    if (accessCode != null) {
      return 'קוד גישה ל${_he[accessCode.group(1)]}';
    }
    final count = RegExp(r'^(\d+) teams$').firstMatch(value);
    if (count != null) return '${count.group(1)} קבוצות';
    final matches = RegExp(r'^(\d+) matches across competitions$')
        .firstMatch(value);
    if (matches != null) {
      return '${matches.group(1)} משחקים מכל התחרויות';
    }
    for (final role in ['Scouter', 'Strategy', 'Leader']) {
      final prefix = '$role • ';
      if (value.startsWith(prefix)) {
        return '${_he[role]} • ${value.substring(prefix.length)}';
      }
    }
    final teamMatch = RegExp(r'^Team (\d+)(?: \((.*)\))?$').firstMatch(value);
    if (teamMatch != null) {
      final name = teamMatch.group(2);
      return name == null
          ? 'קבוצה ${teamMatch.group(1)}'
          : 'קבוצה ${teamMatch.group(1)} ($name)';
    }
    final match = RegExp(r'^Match (\d+)$').firstMatch(value);
    if (match != null) return 'משחק ${match.group(1)}';
    return null;
  }
}

class LocaleSwitchButton extends StatelessWidget {
  const LocaleSwitchButton({super.key});

  @override
  Widget build(BuildContext context) {
    final service = LocaleService.instance;
    return IconButton(
      tooltip: service.text('Language'),
      onPressed: () => service.setLocale(
        service.isHebrew ? const Locale('en') : const Locale('he'),
      ),
      icon: const Icon(Icons.language_rounded),
    );
  }
}
