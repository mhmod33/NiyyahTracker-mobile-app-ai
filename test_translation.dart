import 'package:quran/quran.dart' as q;
void main() {
  print(q.getVerseTranslation(1, 1, translation: q.Translation.enClearQuran));
  print(q.getVerseTranslation(1, 1, translation: q.Translation.enSaheeh));
}
