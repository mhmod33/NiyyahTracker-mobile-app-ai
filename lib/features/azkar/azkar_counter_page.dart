import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/app_colors.dart';

TextStyle _f({double sz = 14, FontWeight fw = FontWeight.w400, Color? c, double? h}) =>
    GoogleFonts.ibmPlexSansArabic(fontSize: sz, fontWeight: fw, color: c, height: h);

// ── Azkar data ──
class Dhikr {
  final String text, reward;
  final int targetCount;
  const Dhikr({required this.text, required this.reward, required this.targetCount});
}

// ── Category definitions ──
class AzkarCategory {
  final String title;
  final List<Dhikr> items;
  const AzkarCategory({required this.title, required this.items});
}

final Map<String, AzkarCategory> azkarCategories = {
  'أذكار الصباح': AzkarCategory(title: 'أذكار الصباح', items: const [
    Dhikr(text: 'أَعُوذُ بِاللهِ مِنْ الشَّيْطَانِ الرَّجِيمِ\nاللّهُ لاَ إِلَـهَ إِلاَّ هُوَ الْحَيُّ الْقَيُّومُ لاَ تَأْخُذُهُ سِنَةٌ وَلاَ نَوْمٌ لَّهُ مَا فِي السَّمَاوَاتِ وَمَا فِي الأَرْضِ مَن ذَا الَّذِي يَشْفَعُ عِنْدَهُ إِلاَّ بِإِذْنِهِ يَعْلَمُ مَا بَيْنَ أَيْدِيهِمْ وَمَا خَلْفَهُمْ وَلاَ يُحِيطُونَ بِشَيْءٍ مِّنْ عِلْمِهِ إِلاَّ بِمَا شَاء وَسِعَ كُرْسِيُّهُ السَّمَاوَاتِ وَالأَرْضَ وَلاَ يَؤُودُهُ حِفْظُهُمَا وَهُوَ الْعَلِيُّ الْعَظِيمُ. [آية الكرسى - البقرة 255]', reward: 'من قالها حين يصبح أجير من الجن حتى يمسى', targetCount: 1),
    Dhikr(text: 'بِسْمِ اللهِ الرَّحْمنِ الرَّحِيم\nقُلْ هُوَ ٱللَّهُ أَحَدٌ، ٱللَّهُ ٱلصَّمَدُ، لَمْ يَلِدْ وَلَمْ يُولَدْ، وَلَمْ يَكُن لَّهُۥ كُفُوًا أَحَدٌۢ.', reward: 'من قالها حين يصبح وحين يمسى كفته من كل شىء (الإخلاص والمعوذتين)', targetCount: 3),
    Dhikr(text: 'بِسْمِ اللهِ الرَّحْمنِ الرَّحِيم\nقُلْ أَعُوذُ بِرَبِّ ٱلْفَلَقِ، مِن شَرِّ مَا خَلَقَ، وَمِن شَرِّ غَاسِقٍ إِذَا وَقَبَ، وَمِن شَرِّ ٱلنَّفَّٰثَٰتِ فِى ٱلْعُقَدِ، وَمِن شَرِّ حَاسِدٍ إِذَا حَسَدَ.', reward: 'المعوذتين', targetCount: 3),
    Dhikr(text: 'بِسْمِ اللهِ الرَّحْمنِ الرَّحِيم\nقُلْ أَعُوذُ بِرَبِّ ٱلنَّاسِ، مَلِكِ ٱلنَّاسِ، إِلَٰهِ ٱلنَّاسِ، مِن شَرِّ ٱلْوَسْوَاسِ ٱلْخَنَّاسِ، ٱلَّذِى يُوَسْوِسُ فِى صُدُورِ ٱلنَّاسِ، مِنَ ٱلْجِنَّةِ وَٱلنَّاسِ.', reward: 'المعوذتين', targetCount: 3),
    Dhikr(text: 'أَصْـبَحْنا وَأَصْـبَحَ المُـلْكُ لله وَالحَمدُ لله ، لا إلهَ إلاّ اللّهُ وَحدَهُ لا شَريكَ لهُ، لهُ المُـلكُ ولهُ الحَمْـد، وهُوَ على كلّ شَيءٍ قدير ، رَبِّ أسْـأَلُـكَ خَـيرَ ما في هـذا اليوم وَخَـيرَ ما بَعْـدَه ، وَأَعـوذُ بِكَ مِنْ شَـرِّ ما في هـذا اليوم وَشَرِّ ما بَعْـدَه، رَبِّ أَعـوذُبِكَ مِنَ الْكَسَـلِ وَسـوءِ الْكِـبَر ، رَبِّ أَعـوذُ بِكَ مِنْ عَـذابٍ في النّـارِ وَعَـذابٍ في القَـبْر.', reward: 'دعاء الصباح', targetCount: 1),
    Dhikr(text: 'اللّهـمَّ أَنْتَ رَبِّـي لا إلهَ إلاّ أَنْتَ ، خَلَقْتَنـي وَأَنا عَبْـدُك ، وَأَنا عَلـى عَهْـدِكَ وَوَعْـدِكَ ما اسْتَـطَعْـت ، أَعـوذُبِكَ مِنْ شَـرِّ ما صَنَـعْت ، أَبـوءُ لَـكَ بِنِعْـمَتِـكَ عَلَـيَّ وَأَبـوءُ بِذَنْـبي فَاغْفـِرْ لي فَإِنَّـهُ لا يَغْـفِرُ الذُّنـوبَ إِلاّ أَنْتَ .', reward: 'من قالها موقنا بها حين يصبح ومات من ليلته دخل الجنة', targetCount: 1),
    Dhikr(text: 'رَضيـتُ بِاللهِ رَبَّـاً وَبِالإسْلامِ ديـناً وَبِمُحَـمَّدٍ صلى الله عليه وسلم نَبِيّـاً.', reward: 'من قالها حين يصبح وحين يمسى كان حقا على الله أن يرضيه يوم القيامة', targetCount: 3),
    Dhikr(text: 'اللّهُـمَّ إِنِّـي أَصْبَـحْتُ أُشْـهِدُك ، وَأُشْـهِدُ حَمَلَـةَ عَـرْشِـك ، وَمَلَائِكَتَكَ ، وَجَمـيعَ خَلْـقِك ، أَنَّـكَ أَنْـتَ اللهُ لا إلهَ إلاّ أَنْـتَ وَحْـدَكَ لا شَريكَ لَـك ، وَأَنَّ ُ مُحَمّـداً عَبْـدُكَ وَرَسـولُـك.', reward: 'من قالها أعتقه الله من النار', targetCount: 4),
    Dhikr(text: 'اللّهُـمَّ ما أَصْبَـَحَ بي مِـنْ نِعْـمَةٍ أَو بِأَحَـدٍ مِـنْ خَلْـقِك ، فَمِـنْكَ وَحْـدَكَ لا شريكَ لَـك ، فَلَـكَ الْحَمْـدُ وَلَـكَ الشُّكْـر.', reward: 'من قالها حين يصبح أدى شكر يومه', targetCount: 1),
    Dhikr(text: 'حَسْبِـيَ اللّهُ لا إلهَ إلاّ هُوَ عَلَـيهِ تَوَكَّـلتُ وَهُوَ رَبُّ العَرْشِ العَظـيم.', reward: 'من قالها كفاه الله ما أهمه من أمر الدنيا والأخرة', targetCount: 7),
    Dhikr(text: 'بِسـمِ اللهِ الذي لا يَضُـرُّ مَعَ اسمِـهِ شَيءٌ في الأرْضِ وَلا في السّمـاءِ وَهـوَ السّمـيعُ العَلـيم.', reward: 'لم يضره من الله شيء', targetCount: 3),
    Dhikr(text: 'اللّهُـمَّ بِكَ أَصْـبَحْنا وَبِكَ أَمْسَـينا ، وَبِكَ نَحْـيا وَبِكَ نَمُـوتُ وَإِلَـيْكَ النُّـشُور.', reward: 'ذكر الصباح', targetCount: 1),
    Dhikr(text: 'أَصْبَـحْـنا عَلَى فِطْرَةِ الإسْلاَمِ، وَعَلَى كَلِمَةِ الإِخْلاَصِ، وَعَلَى دِينِ نَبِيِّنَا مُحَمَّدٍ صَلَّى اللهُ عَلَيْهِ وَسَلَّمَ، وَعَلَى مِلَّةِ أَبِينَا إبْرَاهِيمَ حَنِيفاً مُسْلِماً وَمَا كَانَ مِنَ المُشْرِكِينَ.', reward: 'تجديد العهد', targetCount: 1),
    Dhikr(text: 'سُبْحـانَ اللهِ وَبِحَمْـدِهِ عَدَدَ خَلْـقِه ، وَرِضـا نَفْسِـه ، وَزِنَـةَ عَـرْشِـه ، وَمِـدادَ كَلِمـاتِـه.', reward: 'أثقل في الميزان', targetCount: 3),
    Dhikr(text: 'اللّهُـمَّ عافِـني في بَدَنـي ، اللّهُـمَّ عافِـني في سَمْـعي ، اللّهُـمَّ عافِـني في بَصَـري ، لا إلهَ إلاّ أَنْـتَ.', reward: 'دعاء للعافية', targetCount: 3),
    Dhikr(text: 'اللّهُـمَّ إِنّـي أَعـوذُ بِكَ مِنَ الْكُـفر ، وَالفَـقْر ، وَأَعـوذُ بِكَ مِنْ عَذابِ القَـبْر ، لا إلهَ إلاّ أَنْـتَ.', reward: 'دعاء للعافية', targetCount: 3),
    Dhikr(text: 'اللّهُـمَّ إِنِّـي أسْـأَلُـكَ العَـفْوَ وَالعـافِـيةَ في الدُّنْـيا وَالآخِـرَة ، اللّهُـمَّ إِنِّـي أسْـأَلُـكَ العَـفْوَ وَالعـافِـيةَ في ديني وَدُنْـيايَ وَأهْـلي وَمالـي ، اللّهُـمَّ اسْتُـرْ عـوْراتي وَآمِـنْ رَوْعاتـي ، اللّهُـمَّ احْفَظْـني مِن بَـينِ يَدَيَّ وَمِن خَلْفـي وَعَن يَمـيني وَعَن شِمـالي ، وَمِن فَوْقـي ، وَأَعـوذُ بِعَظَمَـتِكَ أَن أُغْـتالَ مِن تَحْتـي.', reward: 'دعاء جامع', targetCount: 1),
    Dhikr(text: 'يَا حَيُّ يَا قيُّومُ بِرَحْمَتِكَ أسْتَغِيثُ أصْلِحْ لِي شَأنِي كُلَّهُ وَلاَ تَكِلْنِي إلَى نَفْسِي طَـرْفَةَ عَيْنٍ.', reward: 'دعاء مستجاب', targetCount: 3),
    Dhikr(text: 'أَصْبَـحْـنا وَأَصْبَـحْ المُـلكُ للهِ رَبِّ العـالَمـين ، اللّهُـمَّ إِنِّـي أسْـأَلُـكَ خَـيْرَ هـذا الـيَوْم ، فَـتْحَهُ ، وَنَصْـرَهُ ، وَنـورَهُ وَبَـرَكَتَـهُ ، وَهُـداهُ ، وَأَعـوذُ بِـكَ مِـنْ شَـرِّ ما فـيهِ وَشَـرِّ ما بَعْـدَه.', reward: 'دعاء الصباح', targetCount: 1),
    Dhikr(text: 'اللّهُـمَّ عالِـمَ الغَـيْبِ وَالشّـهادَةِ فاطِـرَ السّماواتِ وَالأرْضِ رَبَّ كـلِّ شَـيءٍ وَمَليـكَه ، أَشْهَـدُ أَنْ لا إِلـهَ إِلاّ أَنْت ، أَعـوذُ بِكَ مِن شَـرِّ نَفْسـي وَمِن شَـرِّ الشَّيْـطانِ وَشِرْكِهِ ، وَأَنْ أَقْتَـرِفَ عَلـى نَفْسـي سوءاً أَوْ أَجُـرَّهُ إِلـى مُسْـلِم.', reward: 'دعاء للحفظ', targetCount: 1),
    Dhikr(text: 'أَعـوذُ بِكَلِمـاتِ اللّهِ التّـامّـاتِ مِنْ شَـرِّ ما خَلَـق.', reward: 'دعاء للحفظ', targetCount: 3),
    Dhikr(text: 'اللَّهُمَّ صَلِّ وَسَلِّمْ وَبَارِكْ على نَبِيِّنَا مُحمَّد.', reward: 'من صلى على حين يصبح وحين يمسى ادركته شفاعتى يوم القيامة', targetCount: 10),
    Dhikr(text: 'اللَّهُمَّ إِنَّا نَعُوذُ بِكَ مِنْ أَنْ نُشْرِكَ بِكَ شَيْئًا نَعْلَمُهُ ، وَنَسْتَغْفِرُكَ لِمَا لَا نَعْلَمُهُ.', reward: 'دعاء للحفظ من الشرك', targetCount: 3),
    Dhikr(text: 'اللَّهُمَّ إِنِّي أَعُوذُ بِكَ مِنْ الْهَمِّ وَالْحَزْنِ، وَأَعُوذُ بِكَ مِنْ الْعَجْزِ وَالْكَسَلِ، وَأَعُوذُ بِكَ مِنْ الْجُبْنِ وَالْبُخْلِ، وَأَعُوذُ بِكَ مِنْ غَلَبَةِ الدَّيْنِ، وَقَهْرِ الرِّجَالِ.', reward: 'دعاء جامع', targetCount: 3),
    Dhikr(text: 'أسْتَغْفِرُ اللهَ العَظِيمَ الَّذِي لاَ إلَهَ إلاَّ هُوَ، الحَيُّ القَيُّومُ، وَأتُوبُ إلَيهِ.', reward: 'استغفار', targetCount: 3),
    Dhikr(text: 'يَا رَبِّ , لَكَ الْحَمْدُ كَمَا يَنْبَغِي لِجَلَالِ وَجْهِكَ , وَلِعَظِيمِ سُلْطَانِكَ.', reward: 'حمد لله', targetCount: 3),
    Dhikr(text: 'اللَّهُمَّ إِنِّي أَسْأَلُكَ عِلْمًا نَافِعًا، وَرِزْقًا طَيِّبًا، وَعَمَلًا مُتَقَبَّلًا.', reward: 'دعاء جامع', targetCount: 1),
    Dhikr(text: 'اللَّهُمَّ أَنْتَ رَبِّي لا إِلَهَ إِلا أَنْتَ ، عَلَيْكَ تَوَكَّلْتُ ، وَأَنْتَ رَبُّ الْعَرْشِ الْعَظِيمِ , مَا شَاءَ اللَّهُ كَانَ ، وَمَا لَمْ يَشَأْ لَمْ يَكُنْ ، وَلا حَوْلَ وَلا قُوَّةَ إِلا بِاللَّهِ الْعَلِيِّ الْعَظِيمِ , أَعْلَمُ أَنَّ اللَّهَ عَلَى كُلِّ شَيْءٍ قَدِيرٌ ، وَأَنَّ اللَّهَ قَدْ أَحَاطَ بِكُلِّ شَيْءٍ عِلْمًا , اللَّهُمَّ إِنِّي أَعُوذُ بِكَ مِنْ شَرِّ نَفْسِي ، وَمِنْ شَرِّ كُلِّ دَابَّةٍ أَنْتَ آخِذٌ بِنَاصِيَتِهَا ، إِنَّ رَبِّي عَلَى صِرَاطٍ مُسْتَقِيمٍ.', reward: 'ذكر طيب', targetCount: 1),
    Dhikr(text: 'لَا إلَه إلّا اللهُ وَحْدَهُ لَا شَرِيكَ لَهُ، لَهُ الْمُلْكُ وَلَهُ الْحَمْدُ وَهُوَ عَلَى كُلِّ شَيْءِ قَدِيرِ.', reward: 'كانت له عدل عشر رقاب، وكتبت له مئة حسنة، ومحيت عنه مئة سيئة، وكانت له حرزا من الشيطان', targetCount: 100),
    Dhikr(text: 'سُبْحـانَ اللهِ وَبِحَمْـدِهِ.', reward: 'حُطَّتْ خَطَايَاهُ وَإِنْ كَانَتْ مِثْلَ زَبَدِ الْبَحْرِ', targetCount: 100),
    Dhikr(text: 'أسْتَغْفِرُ اللهَ وَأتُوبُ إلَيْهِ', reward: 'مائة حسنة، ومُحيت عنه مائة سيئة، وكانت له حرزاً من الشيطان حتى يمسى', targetCount: 100),
  ]),
  'أذكار المساء': AzkarCategory(title: 'أذكار المساء', items: const [
    Dhikr(text: 'أَعُوذُ بِاللهِ مِنْ الشَّيْطَانِ الرَّجِيمِ\nاللّهُ لاَ إِلَـهَ إِلاَّ هُوَ الْحَيُّ الْقَيُّومُ لاَ تَأْخُذُهُ سِنَةٌ وَلاَ نَوْمٌ لَّهُ مَا فِي السَّمَاوَاتِ وَمَا فِي الأَرْضِ مَن ذَا الَّذِي يَشْفَعُ عِنْدَهُ إِلاَّ بِإِذْنِهِ يَعْلَمُ مَا بَيْنَ أَيْدِيهِمْ وَمَا خَلْفَهُمْ وَلاَ يُحِيطُونَ بِشَيْءٍ مِّنْ عِلْمِهِ إِلاَّ بِمَا شَاء وَسِعَ كُرْسِيُّهُ السَّمَاوَاتِ وَالأَرْضَ وَلاَ يَؤُودُهُ حِفْظُهُمَا وَهُوَ الْعَلِيُّ الْعَظِيمُ. [آية الكرسى - البقرة 255]', reward: 'من قالها حين يمسى أجير من الجن حتى يصبح', targetCount: 1),
    Dhikr(text: 'أَعُوذُ بِاللهِ مِنْ الشَّيْطَانِ الرَّجِيمِ\nآمَنَ الرَّسُولُ بِمَا أُنْزِلَ إِلَيْهِ مِنْ رَبِّهِ وَالْمُؤْمِنُونَ ۚ كُلٌّ آمَنَ بِاللَّهِ وَمَلَائِكَتِهِ وَكُتُبِهِ وَرُسُلِهِ لَا نُفَرِّقُ بَيْنَ أَحَدٍ مِنْ رُسُلِهِ ۚ وَقَالُوا سَمِعْنَا وَأَطَعْنَا ۖ غُفْرَانَكَ رَبَّنَا وَإِلَيْكَ الْمَصِيرُ. لَا يُكَلِّفُ اللَّهُ نَفْسًا إِلَّا وُسْعَهَا لَهَا مَا كَسَبَتْ وَعَلَيْهَا مَا اكْتَسَبَتْ رَبَّنَا لَا تُؤَاخِذْنَا إِنْ نَّسِينَآ أَوْ أَخْطَأْنَا رَبَّنَا وَلَا تَحْمِلْ عَلَيْنَا إِصْرًا كَمَا حَمَلْتَهُ عَلَى الَّذِينَ مِنْ قَبْلِنَا رَبَّنَا وَلَا تُحَمِّلْنَا مَا لَا طَاقَةَ لَنَا بِهِ وَاعْفُ عَنَّا وَاغْفِرْ لَنَا وَارْحَمْنَا أَنْتَ مَوْلَانَا فَانْصُرْنَا عَلَى الْقَوْمِ الْكَافِرِينَ. [البقرة 285 - 286]', reward: 'من قرأ آيتين من آخر سورة البقرة في ليلة كفتاه', targetCount: 1),
    Dhikr(text: 'بِسْمِ اللهِ الرَّحْمنِ الرَّحِيم\nقُلْ هُوَ ٱللَّهُ أَحَدٌ، ٱللَّهُ ٱلصَّمَدُ، لَمْ يَلِدْ وَلَمْ يُولَدْ، وَلَمْ يَكُن لَّهُۥ كُفُوًا أَحَدٌۢ.', reward: 'من قالها حين يصبح وحين يمسى كفته من كل شىء (الإخلاص والمعوذتين)', targetCount: 3),
    Dhikr(text: 'بِسْمِ اللهِ الرَّحْمنِ الرَّحِيم\nقُلْ أَعُوذُ بِرَبِّ ٱلْفَلَقِ، مِن شَرِّ مَا خَلَقَ، وَمِن شَرِّ غَاسِقٍ إِذَا وَقَبَ، وَمِن شَرِّ ٱلنَّفَّٰثَٰتِ فِى ٱلْعُقَدِ، وَمِن شَرِّ حَاسِدٍ إِذَا حَسَدَ.', reward: 'المعوذتين', targetCount: 3),
    Dhikr(text: 'بِسْمِ اللهِ الرَّحْمنِ الرَّحِيم\nقُلْ أَعُوذُ بِرَبِّ ٱلنَّاسِ، مَلِكِ ٱلنَّاسِ، إِلَٰهِ ٱلنَّاسِ، مِن شَرِّ ٱلْوَسْوَاسِ ٱلْخَنَّاسِ، ٱلَّذِى يُوَسْوِسُ فِى صُدُورِ ٱلنَّاسِ، مِنَ ٱلْجِنَّةِ وَٱلنَّاسِ.', reward: 'المعوذتين', targetCount: 3),
    Dhikr(text: 'أَمْسَيْـنا وَأَمْسـى المـلكُ لله وَالحَمدُ لله ، لا إلهَ إلاّ اللّهُ وَحدَهُ لا شَريكَ لهُ، لهُ المُـلكُ ولهُ الحَمْـد، وهُوَ على كلّ شَيءٍ قدير ، رَبِّ أسْـأَلُـكَ خَـيرَ ما في هـذهِ اللَّـيْلَةِ وَخَـيرَ ما بَعْـدَهـا ، وَأَعـوذُ بِكَ مِنْ شَـرِّ ما في هـذهِ اللَّـيْلةِ وَشَرِّ ما بَعْـدَهـا ، رَبِّ أَعـوذُبِكَ مِنَ الْكَسَـلِ وَسـوءِ الْكِـبَر ، رَبِّ أَعـوذُ بِكَ مِنْ عَـذابٍ في النّـارِ وَعَـذابٍ في القَـبْر.', reward: 'دعاء المساء', targetCount: 1),
    Dhikr(text: 'اللّهـمَّ أَنْتَ رَبِّـي لا إلهَ إلاّ أَنْتَ ، خَلَقْتَنـي وَأَنا عَبْـدُك ، وَأَنا عَلـى عَهْـدِكَ وَوَعْـدِكَ ما اسْتَـطَعْـت ، أَعـوذُبِكَ مِنْ شَـرِّ ما صَنَـعْت ، أَبـوءُ لَـكَ بِنِعْـمَتِـكَ عَلَـيَّ وَأَبـوءُ بِذَنْـبي فَاغْفـِرْ لي فَإِنَّـهُ لا يَغْـفِرُ الذُّنـوبَ إِلاّ أَنْتَ .', reward: 'من قالها موقنا بها حين يمسى ومات من ليلته دخل الجنة', targetCount: 1),
    Dhikr(text: 'رَضيـتُ بِاللهِ رَبَّـاً وَبِالإسْلامِ ديـناً وَبِمُحَـمَّدٍ صلى الله عليه وسلم نَبِيّـاً.', reward: 'من قالها حين يصبح وحين يمسى كان حقا على الله أن يرضيه يوم القيامة', targetCount: 3),
    Dhikr(text: 'اللّهُـمَّ إِنِّـي أَمسيتُ أُشْـهِدُك ، وَأُشْـهِدُ حَمَلَـةَ عَـرْشِـك ، وَمَلَائِكَتَكَ ، وَجَمـيعَ خَلْـقِك ، أَنَّـكَ أَنْـتَ اللهُ لا إلهَ إلاّ أَنْـتَ وَحْـدَكَ لا شَريكَ لَـك ، وَأَنَّ ُ مُحَمّـداً عَبْـدُكَ وَرَسـولُـك.', reward: 'من قالها أعتقه الله من النار', targetCount: 4),
    Dhikr(text: 'اللّهُـمَّ ما أَمسى بي مِـنْ نِعْـمَةٍ أَو بِأَحَـدٍ مِـنْ خَلْـقِك ، فَمِـنْكَ وَحْـدَكَ لا شريكَ لَـك ، فَلَـكَ الْحَمْـدُ وَلَـكَ الشُّكْـر.', reward: 'من قالها حين يمسى أدى شكر يومه', targetCount: 1),
    Dhikr(text: 'حَسْبِـيَ اللّهُ لا إلهَ إلاّ هُوَ عَلَـيهِ تَوَكَّـلتُ وَهُوَ رَبُّ العَرْشِ العَظـيم.', reward: 'من قالها كفاه الله ما أهمه من أمر الدنيا والأخرة', targetCount: 7),
    Dhikr(text: 'بِسـمِ اللهِ الذي لا يَضُـرُّ مَعَ اسمِـهِ شَيءٌ في الأرْضِ وَلا في السّمـاءِ وَهـوَ السّمـيعُ العَلـيم.', reward: 'لم يضره من الله شيء', targetCount: 3),
    Dhikr(text: 'اللّهُـمَّ بِكَ أَمْسَـينا وَبِكَ أَصْـبَحْنا، وَبِكَ نَحْـيا وَبِكَ نَمُـوتُ وَإِلَـيْكَ الْمَصِيرُ.', reward: 'ذكر المساء', targetCount: 1),
    Dhikr(text: 'أَمْسَيْنَا عَلَى فِطْرَةِ الإسْلاَمِ، وَعَلَى كَلِمَةِ الإِخْلاَصِ، وَعَلَى دِينِ نَبِيِّنَا مُحَمَّدٍ صَلَّى اللهُ عَلَيْهِ وَسَلَّمَ، وَعَلَى مِلَّةِ أَبِينَا إبْرَاهِيمَ حَنِيفاً مُسْلِماً وَمَا كَانَ مِنَ المُشْرِكِينَ.', reward: 'تجديد العهد', targetCount: 1),
    Dhikr(text: 'سُبْحـانَ اللهِ وَبِحَمْـدِهِ عَدَدَ خَلْـقِه ، وَرِضـا نَفْسِـه ، وَزِنَـةَ عَـرْشِـه ، وَمِـدادَ كَلِمـاتِـه.', reward: 'أثقل في الميزان', targetCount: 3),
    Dhikr(text: 'اللّهُـمَّ عافِـني في بَدَنـي ، اللّهُـمَّ عافِـني في سَمْـعي ، اللّهُـمَّ عافِـني في بَصَـري ، لا إلهَ إلاّ أَنْـتَ.', reward: 'دعاء للعافية', targetCount: 3),
    Dhikr(text: 'اللّهُـمَّ إِنّـي أَعـوذُ بِكَ مِنَ الْكُـفر ، وَالفَـقْر ، وَأَعـوذُ بِكَ مِنْ عَذابِ القَـبْر ، لا إلهَ إلاّ أَنْـتَ.', reward: 'دعاء للعافية', targetCount: 3),
    Dhikr(text: 'اللّهُـمَّ إِنِّـي أسْـأَلُـكَ العَـفْوَ وَالعـافِـيةَ في الدُّنْـيا وَالآخِـرَة ، اللّهُـمَّ إِنِّـي أسْـأَلُـكَ العَـفْوَ وَالعـافِـيةَ في ديني وَدُنْـيايَ وَأهْـلي وَمالـي ، اللّهُـمَّ اسْتُـرْ عـوْراتي وَآمِـنْ رَوْعاتـي ، اللّهُـمَّ احْفَظْـني مِن بَـينِ يَدَيَّ وَمِن خَلْفـي وَعَن يَمـيني وَعَن شِمـالي ، وَمِن فَوْقـي ، وَأَعـوذُ بِعَظَمَـتِكَ أَن أُغْـتالَ مِن تَحْتـي.', reward: 'دعاء جامع', targetCount: 1),
    Dhikr(text: 'يَا حَيُّ يَا قيُّومُ بِرَحْمَتِكَ أسْتَغِيثُ أصْلِحْ لِي شَأنِي كُلَّهُ وَلاَ تَكِلْنِي إلَى نَفْسِي طَـرْفَةَ عَيْنٍ.', reward: 'دعاء مستجاب', targetCount: 3),
    Dhikr(text: 'أَمْسَيْنا وَأَمْسَى الْمُلْكُ للهِ رَبِّ الْعَالَمَيْنِ، اللَّهُمَّ إِنَّي أسْأَلُكَ خَيْرَ هَذَه اللَّيْلَةِ فَتْحَهَا ونَصْرَهَا، ونُوْرَهَا وبَرَكَتهَا، وَهُدَاهَا، وَأَعُوذُ بِكَ مِنْ شَرِّ مَا فيهِا وَشَرَّ مَا بَعْدَهَا.', reward: 'دعاء المساء', targetCount: 1),
    Dhikr(text: 'اللّهُـمَّ عالِـمَ الغَـيْبِ وَالشّـهادَةِ فاطِـرَ السّماواتِ وَالأرْضِ رَبَّ كـلِّ شَـيءٍ وَمَليـكَه ، أَشْهَـدُ أَنْ لا إِلـهَ إِلاّ أَنْت ، أَعـوذُ بِكَ مِن شَـرِّ نَفْسـي وَمِن شَـرِّ الشَّيْـطانِ وَشِرْكِهِ ، وَأَنْ أَقْتَـرِفَ عَلـى نَفْسـي سوءاً أَوْ أَجُـرَّهُ إِلـى مُسْـلِم.', reward: 'دعاء للحفظ', targetCount: 1),
    Dhikr(text: 'أَعـوذُ بِكَلِمـاتِ اللّهِ التّـامّـاتِ مِنْ شَـرِّ ما خَلَـق.', reward: 'دعاء للحفظ', targetCount: 3),
    Dhikr(text: 'اللَّهُمَّ صَلِّ وَسَلِّمْ وَبَارِكْ على نَبِيِّنَا مُحمَّد.', reward: 'من صلى على حين يصبح وحين يمسى ادركته شفاعتى يوم القيامة', targetCount: 10),
    Dhikr(text: 'اللَّهُمَّ إِنَّا نَعُوذُ بِكَ مِنْ أَنْ نُشْرِكَ بِكَ شَيْئًا نَعْلَمُهُ ، وَنَسْتَغْفِرُكَ لِمَا لَا نَعْلَمُهُ.', reward: 'دعاء للحفظ من الشرك', targetCount: 3),
    Dhikr(text: 'اللَّهُمَّ إِنِّي أَعُوذُ بِكَ مِنْ الْهَمِّ وَالْحَزْنِ، وَأَعُوذُ بِكَ مِنْ الْعَجْزِ وَالْكَسَلِ، وَأَعُوذُ بِكَ مِنْ الْجُبْنِ وَالْبُخْلِ، وَأَعُوذُ بِكَ مِنْ غَلَبَةِ الدَّيْنِ، وَقَهْرِ الرِّجَالِ.', reward: 'دعاء جامع', targetCount: 3),
    Dhikr(text: 'أسْتَغْفِرُ اللهَ العَظِيمَ الَّذِي لاَ إلَهَ إلاَّ هُوَ، الحَيُّ القَيُّومُ، وَأتُوبُ إلَيهِ.', reward: 'استغفار', targetCount: 3),
    Dhikr(text: 'يَا رَبِّ , لَكَ الْحَمْدُ كَمَا يَنْبَغِي لِجَلَالِ وَجْهِكَ , وَلِعَظِيمِ سُلْطَانِكَ.', reward: 'حمد لله', targetCount: 3),
    Dhikr(text: 'لَا إلَه إلّا اللهُ وَحْدَهُ لَا شَرِيكَ لَهُ، لَهُ الْمُلْكُ وَلَهُ الْحَمْدُ وَهُوَ عَلَى كُلِّ شَيْءِ قَدِيرِ.', reward: 'كانت له عدل عشر رقاب، وكتبت له مئة حسنة، ومحيت عنه مئة سيئة، وكانت له حرزا من الشيطان', targetCount: 100),
    Dhikr(text: 'اللَّهُمَّ أَنْتَ رَبِّي لا إِلَهَ إِلا أَنْتَ ، عَلَيْكَ تَوَكَّلْتُ ، وَأَنْتَ رَبُّ الْعَرْشِ الْعَظِيمِ , مَا شَاءَ اللَّهُ كَانَ ، وَمَا لَمْ يَشَأْ لَمْ يَكُنْ ، وَلا حَوْلَ وَلا قُوَّةَ إِلا بِاللَّهِ الْعَلِيِّ الْعَظِيمِ , أَعْلَمُ أَنَّ اللَّهَ عَلَى كُلِّ شَيْءٍ قَدِيرٌ ، وَأَنَّ اللَّهَ قَدْ أَحَاطَ بِكُلِّ شَيْءٍ عِلْمًا , اللَّهُمَّ إِنِّي أَعُوذُ بِكَ مِنْ شَرِّ نَفْسِي ، وَمِنْ شَرِّ كُلِّ دَابَّةٍ أَنْتَ آخِذٌ بِنَاصِيَتِهَا ، إِنَّ رَبِّي عَلَى صِرَاطٍ مُسْتَقِيمٍ.', reward: 'ذكر طيب', targetCount: 1),
    Dhikr(text: 'سُبْحـانَ اللهِ وَبِحَمْـدِهِ.', reward: 'حُطَّتْ خَطَايَاهُ وَإِنْ كَانَتْ مِثْلَ زَبَدِ الْبَحْرِ', targetCount: 100),
  ]),
  'أذكار النوم': AzkarCategory(title: 'أذكار النوم', items: const [
    Dhikr(text: 'باسمك اللهم أموت وأحيا', reward: 'سنة النبي ﷺ عند النوم', targetCount: 1),
    Dhikr(text: 'اللهم قني عذابك يوم تبعث عبادك', reward: 'دعاء قبل النوم', targetCount: 1),
    Dhikr(text: 'سبحان الله', reward: 'تسبيح قبل النوم', targetCount: 33),
    Dhikr(text: 'الحمد لله', reward: 'حمد قبل النوم', targetCount: 33),
    Dhikr(text: 'الله أكبر', reward: 'تكبير قبل النوم', targetCount: 34),
  ]),
  'أذكار بعد الصلاة': AzkarCategory(title: 'أذكار بعد الصلاة', items: const [
    Dhikr(text: 'أستغفر الله', reward: 'استغفار بعد الصلاة', targetCount: 3),
    Dhikr(text: 'اللهم أنت السلام ومنك السلام تباركت يا ذا الجلال والإكرام', reward: 'سنة بعد السلام', targetCount: 1),
    Dhikr(text: 'سبحان الله', reward: 'يغرس لك نخلة في الجنة', targetCount: 33),
    Dhikr(text: 'الحمد لله', reward: 'تملأ الميزان', targetCount: 33),
    Dhikr(text: 'الله أكبر', reward: 'تملأ ما بين السماء والأرض', targetCount: 34),
    Dhikr(text: 'لا إله إلا الله وحده لا شريك له، له الملك وله الحمد وهو على كل شيء قدير', reward: 'لم يأتِ أحد بأفضل مما جاء به', targetCount: 1),
  ]),
  'أدعية نبوية': AzkarCategory(title: 'أدعية نبوية', items: const [
    Dhikr(text: 'اللهم إني أعوذ بك من الهم والحزن والعجز والكسل والبخل والجبن وضلع الدين وغلبة الرجال', reward: 'دعاء جامع', targetCount: 3),
    Dhikr(text: 'اللهم أصلح لي ديني الذي هو عصمة أمري وأصلح لي دنياي التي فيها معاشي', reward: 'دعاء شامل', targetCount: 1),
    Dhikr(text: 'ربنا آتنا في الدنيا حسنة وفي الآخرة حسنة وقنا عذاب النار', reward: 'أكثر دعاء النبي ﷺ', targetCount: 7),
    Dhikr(text: 'اللهم إني أسألك الهدى والتقى والعفاف والغنى', reward: 'من جوامع الدعاء', targetCount: 3),
    Dhikr(text: 'اللهم صلّ وسلم على نبينا محمد', reward: 'صلّى الله عليه بها عشراً', targetCount: 100),
  ]),
  'عام': AzkarCategory(title: 'عدّاد الأذكار', items: const [
    Dhikr(text: 'سبحان الله', reward: 'يغرس لك نخلة في الجنة', targetCount: 33),
    Dhikr(text: 'الحمد لله', reward: 'تملأ الميزان', targetCount: 33),
    Dhikr(text: 'الله أكبر', reward: 'تملأ ما بين السماء والأرض', targetCount: 34),
    Dhikr(text: 'لا إله إلا الله', reward: 'أفضل ما قلت أنا والنبيون من قبلي', targetCount: 100),
    Dhikr(text: 'سبحان الله وبحمده', reward: 'حُطّت خطاياه وإن كانت مثل زبد البحر', targetCount: 100),
    Dhikr(text: 'لا حول ولا قوة إلا بالله', reward: 'كنز من كنوز الجنة', targetCount: 100),
    Dhikr(text: 'أستغفر الله', reward: 'من لزم الاستغفار جعل الله له من كل همّ فرجاً', targetCount: 100),
    Dhikr(text: 'اللهم صلّ وسلم على نبينا محمد', reward: 'صلّى الله عليه بها عشراً', targetCount: 100),
    Dhikr(text: 'سبحان الله وبحمده سبحان الله العظيم', reward: 'كلمتان حبيبتان إلى الرحمن ثقيلتان في الميزان', targetCount: 100),
  ]),
};

class AzkarCounterPage extends StatefulWidget {
  final String categoryKey;
  const AzkarCounterPage({super.key, this.categoryKey = 'عام'});
  @override
  State<AzkarCounterPage> createState() => _AzkarCounterPageState();
}

class _AzkarCounterPageState extends State<AzkarCounterPage> with SingleTickerProviderStateMixin {
  int _selectedIndex = 0;
  late List<Dhikr> _azkar;
  late List<int> _counts;
  late String _title;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    final cat = azkarCategories[widget.categoryKey] ?? azkarCategories['عام']!;
    _azkar = cat.items;
    _title = cat.title;
    _counts = List.filled(_azkar.length, 0);
    _pulseController = AnimationController(vsync: this, duration: const Duration(milliseconds: 150));
    _pulseAnim = Tween<double>(begin: 1.0, end: 0.92).animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut));
  }

  @override
  void dispose() { _pulseController.dispose(); super.dispose(); }

  Dhikr get _current => _azkar[_selectedIndex];
  int get _currentCount => _counts[_selectedIndex];
  double get _progress => (_currentCount / _current.targetCount).clamp(0.0, 1.0);
  bool get _completed => _currentCount >= _current.targetCount;

  void _increment() {
    if (_completed) return;
    HapticFeedback.lightImpact();
    _pulseController.forward().then((_) => _pulseController.reverse());
    setState(() { _counts[_selectedIndex]++; });
    if (_counts[_selectedIndex] >= _current.targetCount) HapticFeedback.heavyImpact();
  }

  void _reset() => setState(() => _counts[_selectedIndex] = 0);
  void _resetAll() => setState(() { _counts = List.filled(_azkar.length, 0); });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0A0A0A) : AppColors.background;
    final cardBg = isDark ? const Color(0xFF1A1F1C) : AppColors.cardBg;
    final textColor = isDark ? Colors.white : AppColors.textPrimary;
    final subColor = isDark ? Colors.white54 : AppColors.gray;
    final greenColor = isDark ? AppColors.lightGreen : AppColors.darkGreen;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: bg,
        appBar: AppBar(
          backgroundColor: cardBg, elevation: 0, scrolledUnderElevation: 1,
          leading: Padding(
            padding: const EdgeInsets.all(8.0),
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                decoration: BoxDecoration(color: textColor.withOpacity(0.1), shape: BoxShape.circle),
                child: Icon(Icons.arrow_forward_ios_rounded, color: textColor, size: 18),
              ),
            ),
          ),
          title: Text('📿 $_title', style: _f(fw: FontWeight.w800, sz: 20, c: textColor)),
          actions: [IconButton(icon: Icon(Icons.restart_alt, color: subColor), tooltip: 'إعادة ضبط الكل', onPressed: _resetAll)],
        ),
        body: Column(children: [
          // ── Azkar selector ──
          SizedBox(height: 52, child: ListView.builder(
            scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            itemCount: _azkar.length,
            itemBuilder: (_, i) {
              final selected = i == _selectedIndex;
              final done = _counts[i] >= _azkar[i].targetCount;
              return GestureDetector(
                onTap: () => setState(() => _selectedIndex = i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: selected ? AppColors.darkGreen : done ? (isDark ? AppColors.darkGreen.withOpacity(0.2) : AppColors.paleGreen) : (isDark ? Colors.white10 : cardBg),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: selected ? AppColors.darkGreen : (isDark ? Colors.white24 : AppColors.grayLight)),
                  ),
                  child: Center(child: Row(children: [
                    if (done) Padding(padding: const EdgeInsets.only(left: 4), child: Icon(Icons.check_circle, size: 14, color: isDark ? AppColors.lightGreen : AppColors.darkGreen)),
                    Text('${i + 1}', style: _f(fw: FontWeight.w800, sz: 13, c: selected ? Colors.white : textColor)),
                  ])),
                ),
              );
            },
          )),
          // ── Main counter ──
          Expanded(child: GestureDetector(
            onTap: _increment, behavior: HitTestBehavior.opaque,
            child: Padding(padding: const EdgeInsets.symmetric(horizontal: 24), child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(_current.text, textAlign: TextAlign.center, style: _f(sz: 26, fw: FontWeight.w900, c: greenColor, h: 1.7)),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(color: isDark ? AppColors.gold.withOpacity(0.15) : AppColors.goldLight, borderRadius: BorderRadius.circular(12)),
                  child: Text(_current.reward, textAlign: TextAlign.center, style: _f(sz: 13, fw: FontWeight.w600, c: isDark ? AppColors.goldLight : AppColors.dark)),
                ),
                const SizedBox(height: 36),
                ScaleTransition(scale: _pulseAnim, child: Container(
                  width: 180, height: 180,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle, color: cardBg,
                    boxShadow: [BoxShadow(color: (_completed ? AppColors.lightGreen : AppColors.darkGreen).withOpacity(0.15), blurRadius: 30, spreadRadius: 5)],
                  ),
                  child: Stack(alignment: Alignment.center, children: [
                    SizedBox(width: 170, height: 170, child: CircularProgressIndicator(
                      value: _progress, strokeWidth: 6,
                      backgroundColor: isDark ? Colors.white12 : AppColors.grayLight,
                      color: _completed ? AppColors.lightGreen : AppColors.darkGreen, strokeCap: StrokeCap.round)),
                    Column(mainAxisSize: MainAxisSize.min, children: [
                      if (_completed) const Text('✅', style: TextStyle(fontSize: 28))
                      else Text('$_currentCount', style: _f(sz: 52, fw: FontWeight.w900, c: greenColor)),
                      Text('/ ${_current.targetCount}', style: _f(sz: 16, fw: FontWeight.w600, c: subColor)),
                    ]),
                  ]),
                )),
                const SizedBox(height: 24),
                Text(_completed ? 'أحسنت! أكملت هذا الذكر ✨' : 'اضغط في أي مكان للعدّ',
                  style: _f(sz: 14, c: _completed ? greenColor : subColor, fw: FontWeight.w600)),
              ],
            )),
          )),
          // ── Bottom controls ──
          Container(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
            decoration: BoxDecoration(color: cardBg, boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.3 : 0.04), blurRadius: 10, offset: const Offset(0, -4))]),
            child: Row(children: [
              Expanded(child: OutlinedButton.icon(
                onPressed: _reset, icon: Icon(Icons.refresh, size: 18, color: subColor),
                label: Text('إعادة', style: _f(fw: FontWeight.w700, c: subColor)),
                style: OutlinedButton.styleFrom(foregroundColor: subColor, side: BorderSide(color: isDark ? Colors.white24 : AppColors.grayLight),
                  padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
              )),
              const SizedBox(width: 12),
              Expanded(child: ElevatedButton.icon(
                onPressed: _selectedIndex > 0 ? () => setState(() => _selectedIndex--) : null,
                icon: const Icon(Icons.arrow_forward, size: 18),
                label: Text('السابق', style: _f(fw: FontWeight.w700)),
                style: ElevatedButton.styleFrom(backgroundColor: isDark ? Colors.white10 : AppColors.surfaceLight, foregroundColor: greenColor,
                  disabledForegroundColor: subColor, elevation: 0, padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
              )),
              const SizedBox(width: 12),
              Expanded(child: ElevatedButton.icon(
                onPressed: _selectedIndex < _azkar.length - 1 ? () => setState(() => _selectedIndex++) : null,
                icon: const Icon(Icons.arrow_back, size: 18),
                label: Text('التالي', style: _f(fw: FontWeight.w700)),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.darkGreen, foregroundColor: Colors.white,
                  elevation: 0, padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
              )),
            ]),
          ),
        ]),
      ),
    );
  }
}
