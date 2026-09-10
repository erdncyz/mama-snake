# Firebase Setup

Bu depo `mamba-snake-4532c` Firebase projesine baglidir.

## Yapilandirilan servisler

- iOS app: `com.mamba.snake`
- Cloud Firestore: `(default)`, `eur3`, Standard edition
- Firebase Authentication: Anonymous provider
- Firebase Analytics and Crashlytics
- Firestore collection: `scores`
- Security rules: `firestore.rules`
- Remote Config template is empty (unused; ads are always enabled in-app)

## Deploy

Firebase CLI ile oturum actiktan sonra:

```sh
npx firebase-tools deploy --only auth,firestore,remoteconfig
```

`GoogleService-Info.plist` uygulama hedefinde bulunur. Firebase konsolunda yeni bir
iOS app kaydi olusturulursa bu dosya yeni kaydin dosyasiyla degistirilmelidir.

## Leaderboard

Solo sonuclari kullanici kimligine gore `scores` koleksiyonunda tutulur.

Crashlytics dSYM yukleme script'i Xcode target build phase'ine eklenmistir.
