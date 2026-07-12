# Firebase Setup

Bu depo `mamba-snake-4532c` Firebase projesine baglidir.

## Yapilandirilan servisler

- iOS app: `com.mamba.snake`
- Cloud Firestore: `(default)`, `eur3`, Standard edition
- Firebase Authentication: Anonymous provider
- Firebase Analytics and Crashlytics
- Firebase Remote Config: online mode, leaderboard, snapshot and ad controls
- Firestore collections: `scores`, `multiplayerScores`, `rooms`
- Security rules: `firestore.rules`

## Deploy

Firebase CLI ile oturum actiktan sonra:

```sh
npx firebase-tools deploy --only auth,firestore,remoteconfig
```

`GoogleService-Info.plist` uygulama hedefinde bulunur. Firebase konsolunda yeni bir
iOS app kaydi olusturulursa bu dosya yeni kaydin dosyasiyla degistirilmelidir.

## Multiplayer mimarisi

Host cihaz iki bocegin, yilanin ve oyun alaninin otoritesidir. Konuk cihaz yalnizca
yon degisikliklerini yazar; host oyun snapshot'ini saniyede yaklasik 5 kez Firestore'a
yazar. Oda kodlari 6 karakterdir ve oda sorgulari kurallar tarafindan kapatilmistir.

Firestore Spark kotasinda toplam 20.000 yazma/gun siniri vardir. Uzun sureli veya
yuksek eszamanli oyuncu trafiginde Blaze plana gecmek ya da pozisyon senkronizasyonunu
Realtime Database'e tasimak gerekir.

## Leaderboard

Solo sonuclari kullanici kimligine gore `scores` koleksiyonunda, iki oyunculu takim
sonuclari oda koduna gore `multiplayerScores` koleksiyonunda tutulur. Co-op skorunu
yalnizca odanin host oyuncusu yazabilir; her iki oyuncu da sonucu kendi co-op
leaderboard'unda gorur.

## Remote Config

- `multiplayer_enabled`
- `leaderboard_limit`
- `multiplayer_snapshot_interval_ms`
- `interstitial_ads_enabled`
- `rewarded_ads_enabled`

Crashlytics dSYM yukleme script'i Xcode target build phase'ine eklenmistir.