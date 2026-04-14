import 'dart:async';

import 'package:flame/flame.dart';
import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';

import 'l10n/app_localizations.dart';

import 'logic/ad_service.dart';
import 'logic/shared_functions.dart';
import 'model/app_model.dart';
import 'model/user_preferences.dart';
import 'views/main_menu_view.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  await dotenv.load(fileName: '.env');

  // Render first frame immediately — no more awaiting MobileAds.init here.
  runApp(
    ChangeNotifierProvider(
      create: (context) => AppModel(),
      child: Chess(),
    ),
  );

  // Heavy work in background after UI is visible:
  // 1. Initialize Mobile Ads SDK (500 ms – 2 s on Android)
  // 2. Pre-load interstitial ad queue
  // 3. Pre-load Flame images & audio
  unawaited(_warmUpServices());
}

Future<void> _warmUpServices() async {
  final initStatus = await MobileAds.instance.initialize();

  // Register emulator + physical test devices so test ad units get filled.
  await MobileAds.instance.updateRequestConfiguration(
    RequestConfiguration(testDeviceIds: AdService.instance.testDeviceIds),
  );

  debugPrint('[Ads] SDK init done: '
      '${initStatus.adapterStatuses.entries.map((e) => '${e.key}: ${e.value.state}').join(', ')}');

  AdService.instance.markSdkReady();
  AdService.instance.fillQueue();
  await _loadFlameAssets();
}

Future<void> _loadFlameAssets() async {
  List<String> pieceImages = [];
  for (var theme in PIECE_THEMES) {
    for (var color in ['black', 'white']) {
      for (var piece in ['king', 'queen', 'rook', 'bishop', 'knight', 'pawn']) {
        pieceImages
            .add('pieces/${formatPieceTheme(theme)}/${piece}_$color.png');
      }
    }
  }
  await Flame.images.loadAll(pieceImages);
  await FlameAudio.audioCache.loadAll([
    'piece_moved.mp3',
    'win.wav',
    'lose.wav',
    'tie.wav',
  ]);
}

class Chess extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<AppModel>(
      builder: (context, appModel, _) {
        return CupertinoApp(
          debugShowCheckedModeBanner: false,
          title: 'Infinite Chess AI',
          locale: appModel.locale,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [
            Locale('en'),
            Locale('vi'),
          ],
          theme: CupertinoThemeData(
            brightness: Brightness.dark,
            textTheme: CupertinoTextThemeData(
              textStyle: GoogleFonts.inter(fontSize: 16),
              pickerTextStyle: GoogleFonts.inter(),
            ),
          ),
          home: MainMenuView(),
        );
      },
    );
  }
}
