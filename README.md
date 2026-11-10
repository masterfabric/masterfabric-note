<p align="center">
  <img src="docs/app-icon.png" width="160" alt="Note uygulama ikonu" />
</p>

<h1 align="center">Note</h1>

<p align="center">
  Klasik siyah mermer desenli okul defterinin iPhone, iPad, iPhone Duo ve Apple Watch için yeni nesil hâli.
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Swift-5-F05138?logo=swift&logoColor=white" alt="Swift 5" />
  <img src="https://img.shields.io/badge/SwiftUI-100%25-0A84FF?logo=swift&logoColor=white" alt="SwiftUI" />
  <img src="https://img.shields.io/badge/iOS-18%2B-000000?logo=apple&logoColor=white" alt="iOS 18+" />
  <img src="https://img.shields.io/badge/watchOS-11%2B-000000?logo=apple&logoColor=white" alt="watchOS 11+" />
  <img src="https://img.shields.io/badge/iPhone%20Duo-mente%C5%9Fe%20deste%C4%9Fi-111111" alt="iPhone Duo menteşe desteği" />
  <img src="https://img.shields.io/badge/Apple%20Pencil-PencilKit-FF9F0A" alt="Apple Pencil, PencilKit" />
  <img src="https://img.shields.io/badge/Xcode-27-147EFB?logo=xcode&logoColor=white" alt="Xcode 27" />
</p>

<p align="center">
  <a href="https://masterfabric.co">masterfabric.co</a> ·
  Yazar: <a href="https://github.com/gurkanfikretgunak">Gürkan Fikret Günak</a> ·
  <code>com.masterfabric.note</code>
</p>

<p align="center">
  <img src="docs/iphone-library.png" width="260" alt="Defterler ekranı" />
</p>

## Özellikler

**Defter**

- Siyah mermer desenli, siyah sırtlı, etiketli klasik kapak; 7 renk, 4 soyut desen (mermer, dalgalar, halkalar, mozaik) ya da galeriden kapak fotoğrafı.
- A4 oranında 6 kâğıt tipi: kareli (5 mm), çizgili, kılavuz çizgili, noktalı, geometrik, düz. Kâğıt ekranı kenardan kenara kaplar.
- Sayfa geçişi: 3D sayfa kıvırma ya da 2D kaydırma.
- Okuma modu, açık / koyu tema ve sıcak tonlu okuma kâğıdı.

**Yazım ve çizim**

- PencilKit ile Apple Pencil ya da parmakla çizim; isteğe bağlı "yalnızca Pencil" modu.
- Klavyeyle sayfaya yazı.
- Çıkartmalar ve nesneler: beyaz kenarlı çıkartmalar, yardımcı etiketler (YAPILACAK, ÖNEMLİ, FİKİR, bugünün tarihi…), yapışkan notlar, bant, 5 stilde metin kutusu ve şekiller. Sürüklerken kalkar, bırakınca dokunsal geri bildirimle sayfaya yapışır; tutamaçla büyütülür ve döndürülür.

**Hızlı eylemler ve paylaşım**

- Sayfayı görsel, defteri PDF olarak paylaşma.
- Yapay zekâ agent'larına gönderme: sayfa görseli, cihazda tanınan el yazısı ve hazır istem (özetle, yapılacaklar listesine çevir, temize çek) paylaşım sayfasına verilir.
- Ana ekran kısayolları, Siri / Kısayollar eylemleri ve `mfnote://quick`, `mfnote://new`, `mfnote://continue` bağlantıları.
- Ana ekran ve kilit ekranı widget'ı.

**Apple Watch**

- Defter listesi, son notlar ve bilekten hızlı not; not telefondaki "Hızlı Notlar" defterine düşer.

## iPhone Duo

Katlanabilir ekran için iOS 27.1 menteşe API'si (`onHingeChange`) kullanılır:

- **Katlıyken** ekranda açık olan defterin kendi kapağı tam ekran görünür (rengi, deseni ya da fotoğrafı neyse o). Kapağın altında *Aç*, *Hızlı Not* ve *Kapağı Değiştir* düğmeleri bulunur.
- **Açılırken** kapak, menteşe açısına göre sırt kenarı etrafında döner ve sayfayı ortaya çıkarır.
- **Açıkken** kâğıt geniş ekranın tamamını kaplar; A4 alanının dışına da yazılabilir.
- Ayarlar → *Katlıyken kapağı göster* ile kapatılabilir.

## Teknoloji

| Katman | Kullanılan |
| --- | --- |
| Arayüz | SwiftUI, Observation (`@Observable`) |
| Çizim | PencilKit (`PKCanvasView`, `PKToolPicker`) |
| Sayfa geçişi | `UIPageViewController` (page curl / scroll) |
| El yazısı tanıma | Vision (`VNRecognizeTextRequest`), cihaz üzerinde |
| Kısayollar | App Intents, `UIApplicationShortcutItem`, URL şeması |
| Widget | WidgetKit, App Group ile veri paylaşımı |
| Saat | WatchConnectivity |
| Katlanabilir | SwiftUI `onHingeChange` / `DeviceHinge` |
| Proje | XcodeGen (`project.yml`) |
| Diller | İngilizce, Türkçe (String Catalog) |

Üçüncü taraf bağımlılık yoktur. Veriler cihazda kalır: `library.json` ve sayfa başına bir PencilKit dosyası.

## Proje yapısı

```
Note/          iOS uygulaması (iPhone, iPad, Duo)
  Views/       Kütüphane, kapak, kâğıt, sayfa, çıkartmalar, ayarlar, menteşe kapağı
  Tools/       Dışa aktarım, el yazısı tanıma, App Intents, saat ve widget köprüsü
NoteWatch/     watchOS uygulaması
NoteWidget/    Ana ekran ve kilit ekranı widget'ı
Shared/        Ortak model ve çeviriler
scripts/       App icon üretici betik
```

## Çalıştırma

Gereken: Xcode 27 ve [XcodeGen](https://github.com/yonaskolb/XcodeGen).

```bash
xcodegen generate
```

```bash
open Note.xcodeproj
```

Gerçek cihaz için Xcode'da imzalama ekibini seçin ve `group.com.masterfabric.note` uygulama grubunu etkinleştirin (widget verisi bu grup üzerinden paylaşılır).

App icon'u yeniden üretmek için:

```bash
swift scripts/make-icon.swift docs/app-icon.png
```

## Durum

- iPhone ve iPhone Duo simülatörlerinde denendi.
- Apple Watch uygulaması ve widget derleniyor; henüz bir cihazda ya da simülatörde çalıştırılarak denenmedi.
- Çeviriler makine yazımıdır.

## Yazar

**Gürkan Fikret Günak** — [MasterFabric](https://masterfabric.co) · [@gurkanfikretgunak](https://github.com/gurkanfikretgunak)
