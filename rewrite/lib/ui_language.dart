/// UI language preference, independent of translation direction.
/// Set by the app root when preferences are restored or changed.
class UiLanguage {
  static String code='ar';
  static bool get arabic=>code!='en';
  static String t(String ar,String en)=>arabic?ar:en;
}
