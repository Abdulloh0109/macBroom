# MacBroom — qo'llanma

MacBroom — Mac uchun bepul tozalash dasturi. CleanMyMac qiladigan ishlarning asosiy qismini
qiladi, lekin pullik emas, reklama ko'rsatmaydi va internetga umuman chiqmaydi.

Swift + SwiftUI'da yozilgan, hech qanday tashqi kutubxona ishlatmaydi, hajmi 2.7 MB.

---

## Mundarija

1. [Ochish va o'rnatish](#1-ochish-va-ornatish)
2. [Tavsiya belgilari — nimaga tegish mumkin](#2-tavsiya-belgilari)
3. [Aqlli tekshiruv](#3-aqlli-tekshiruv) — kesh va keraksiz fayllarni tozalash
4. [Disk xaritasi](#4-disk-xaritasi) — joy qayerga ketgan
5. [Katta va eski fayllar](#5-katta-va-eski-fayllar)
6. [Loyihalar](#6-loyihalar) — node_modules, build, Pods
7. [O'rnatilgan ilovalar](#7-ornatilgan-ilovalar)
8. [Yashirin ilovalar](#8-yashirin-ilovalar)
9. [Fonda ishlayotganlar](#9-fonda-ishlayotganlar)
10. [Avtomatik xizmatlar](#10-avtomatik-xizmatlar)
11. [Xavfsizlik — nima uchun buzib qo'ymaydi](#11-xavfsizlik)
12. [Terminal rejimi](#12-terminal-rejimi)
13. [Tez-tez beriladigan savollar](#13-savollar)

---

## 1. Ochish va o'rnatish

```bash
git clone https://github.com/Abdulloh0109/macBroom.git
cd macBroom
./Scripts/build_app.sh release
open build/MacBroom.app
```

Doim qo'l ostida turishi uchun `MacBroom.app` ni `/Applications` papkasiga sudrab tashlang.

Dastur "ad-hoc" imzo bilan yig'ilgan (Apple'ga pul to'lanmagan), shuning uchun macOS birinchi
ochishda ogohlantirishi mumkin. Yechimi: ilovaga **o'ng tugma → Open**, keyin **Open** ni bosing.
Bir marta shunday qilsangiz, keyin oddiy ochiladi.

**Tilni almashtirish:** chap ustunning pastida til ro'yxati bor. Sakkizta til:
o'zbek, ingliz, rus, turk, nemis, ispan, fransuz va xitoy. Tanlaganingiz bilan butun
interfeys o'zgaradi, dasturni qayta ochish shart emas. Birinchi ochilishda dastur
tizim tilini tanlaydi, mos til topilmasa o'zbekcha bo'ladi.

**Chap pastdagi halqa** haqiqiy bo'sh joyni ko'rsatadi — `df` buyrug'i bilan bir xil raqam.
Tagida esa alohida yozuv turadi: *"+84,88 GB ni macOS kerak bo'lganda bo'shatadi"*. Bu
"purgeable" deb ataladigan joy — kesh va iCloud'ga yuklab yuborilishi mumkin bo'lgan
fayllar. macOS ba'zi joylarda uni bo'sh joy sifatida ko'rsatadi, lekin u hali sizniki emas,
shuning uchun MacBroom ikkalasini aralashtirmaydi.

Ikonkani ham yasab olmoqchi bo'lsangiz (ixtiyoriy):

```bash
./Scripts/make_icon.swift .
```

---

## 2. Tavsiya belgilari

Dastur "mana shu narsalar bor" deb qo'ya qolmaydi — har birining yoniga **nima qilish
kerakligini** yozib qo'yadi. To'rtta belgi bor:

| Belgi | Rangi | Ma'nosi |
| --- | --- | --- |
| **O'chirish mumkin** | ko'k-yashil | Buni hech kim ishlatmayapti, bemalol o'chiring |
| **Ortiqcha** | sariq | Buni ochgan ilova allaqachon yopilgan — birinchi navbatda shuni tozalang |
| **Ishlatilmoqda** | yashil | Hozir kimdir ishlatyapti — tegmang |
| **Tegmang** | kulrang | macOS'ga kerak. Yopsangiz ham o'zi qaytadan ishga tushadi |

**Tegmang** belgisi turgan qatorda *Yopish* tugmasi umuman bosilmaydi — xato bosib
qo'yishning iloji yo'q.

### Port belgisi

Agar dastur biror portni band qilib turgan bo'lsa, yoniga yashil rangda **`8082-port`**
kabi belgi chiqadi va u avtomatik **Ishlatilmoqda** deb baholanadi.

Bu aynan "men 8082 ni ishlatib turibman" degan holat uchun: dev-serveringiz
ro'yxatda ko'rinadi, porti yozilgan bo'ladi va dastur uni yopishni tavsiya qilmaydi.

Muhim jihati: `npm run web`, `node`, `python -m http.server` kabi terminaldan
ishga tushirilgan dasturlar macOS uchun "ilova" hisoblanmaydi va odatdagi
ro'yxatlarda **ko'rinmaydi**. MacBroom port band qilgan har bir jarayonni
alohida qo'shib chiqadi, shuning uchun ular ham ro'yxatga tushadi.

### "Ilova ochiq" belgisi

Aqlli tekshiruvda kesh papkasini ochsangiz, ba'zi qatorlarda sariq **Ilova ochiq**
belgisi turadi. Bu — o'sha keshning egasi bo'lgan ilova hozir ishlab turibdi degani.
O'chirsangiz ham bo'ladi, lekin ilova keshni darrov qaytadan yozadi, shuning uchun
avval ilovani yopganingiz ma'qul.

---

## 3. Aqlli tekshiruv

![Aqlli tekshiruv](docs/uz-smart-scan.png)

Eng ko'p ishlatiladigan bo'lim. **Tekshirish** tugmasini bosasiz — dastur kesh, log va
dasturchi fayllarini qidiradi, topganini bo'limlarga ajratib ko'rsatadi.

Qaysi joylarni ko'radi:

| Bo'lim                       | Nimani o'z ichiga oladi                                                             |
| ---------------------------- | ----------------------------------------------------------------------------------- |
| Ilovalar keshi               | `~/Library/Caches` — ilovalar o'zi qayta yaratadigan vaqtinchalik fayllar           |
| Dasturchi keshi              | npm, yarn, pnpm, Bun, Deno, CocoaPods, Homebrew, pip, Gradle, Cargo, Go, `~/.cache` |
| Xcode chiqindilari           | DerivedData, arxivlar, iOS/watchOS/tvOS qurilma fayllari, simulyator keshi          |
| Brauzer keshi                | Chrome, Safari, Firefox, Brave, Edge, Arc                                           |
| Loglar va xato hisobotlari   | `~/Library/Logs`, CrashReporter                                                     |
| Mail yuklamalari             | Mail ilovasi xatlardan nusxalab olgan biriktirmalar                                 |
| Savat                        | Savatda turgan fayllar                                                              |
| Eski o'rnatuvchi fayllar     | `~/Downloads` dagi 60 kundan eski `.dmg`, `.pkg`, `.iso`, `.zip`                    |
| iPhone/iPad zaxira nusxalari | Kompyuterdagi zaxira nusxalar                                                       |

**"Xavfsiz" va "Tekshiring" belgilari.** Yashil _Xavfsiz_ belgisi — bu fayllar kerak
bo'lganda o'zi qayta yaratiladi, bemalol o'chiravering. Sariq _Tekshiring_ belgisi —
zaxira nusxa yoki yuklab olingan fayl bo'lishi mumkin, shuning uchun dastur ularni
**o'zi tanlamaydi**, siz qo'lda belgilashingiz kerak.

**Ishlatish tartibi:**

1. **Tekshirish** ni bosing (odatda 4–6 soniya).
2. Bo'lim yonidagi `>` belgisini bosib, ichida aynan nima borligini ko'ring.
3. Keraksizlarini belgilab (yoki _Faqat xavfsizlari_ ni bosib) **Savatga tashlash** ni bosing.
4. Tasdiqlash oynasi chiqadi — **Savatga tashlash** ni yana bosasiz.

Fayllar **Savatga** tushadi, butunlay o'chmaydi. Xato qilsangiz Savatdan qaytarib olasiz.
Joy haqiqatan bo'shashi uchun keyin Savatni tozalashingiz kerak.

> **Maslahat:** kesh o'chirilganda ochiq turgan ilova o'zini g'alati tutishi mumkin
> (masalan brauzer sahifalarni qaytadan yuklaydi). Bu zarar emas. Iloji bo'lsa
> tozalashdan oldin ilovalarni yopib qo'ying.

---

## 4. Disk xaritasi

![Disk xaritasi](docs/uz-disk-map.png)

"Disk band, lekin qayerga ketgan?" degan savolga ro'yxat emas, rasm bilan javob beradi.
Har bir pufakning **yuzasi** papkaning hajmiga to'g'ri proporsional — ikki barobar
katta papka ikki barobar katta yuza egallaydi (eni emas, yuzasi).

- Pufakni **bosing** — ichiga kirasiz, o'tish animatsiya bilan bo'ladi.
- **Yuqoriga** tugmasi yoki tepadagi yo'lni bosib orqaga qaytasiz.
- Pufakni **o'ng tugma** bilan bossangiz Finder'da ochiladi.
- Sichqonchani olib borsangiz pufak biroz kattalashib, yorishadi.
- Juda mayda papkalar bitta kulrang pufakka yig'iladi, aks holda ekran nuqtalarga to'lib ketardi.

Yuqoridagi rasm shu Mac'niki: `Library` 44,89 GB (52%), `.android` 22,42 GB (26%),
`Progects` 12,18 GB (14%). Ya'ni uy papkasining chorak qismini Android emulyatorlari
egallab turibdi — buni ro'yxatdan topish qiyin, xaritada esa darrov ko'rinadi.

**Qanchalik tez.** Butun uy papkasi (100 mingdan ortiq fayl, 85 GB) **~20 soniyada**
o'lchanadi. Bitta o'tishda butun daraxt tuziladi, shuning uchun keyin katakdan
katakka kirish bir zumda bo'ladi — qayta o'lchash kerak emas.

> Raqamlar `du` bilan solishtirilgan va mos keladi. Farq faqat birlikda: `du` **GiB**
> (1024 asosida), MacBroom esa **GB** (1000 asosida) ko'rsatadi. 11,28 GiB = 12,11 GB.

---

## 5. Katta va eski fayllar

![Katta va eski fayllar](docs/uz-large-files.png)

"Disk to'lib ketdi, lekin nima band qilyapti?" degan savolga javob beradi.

- **Papka tugmasi** — qaysi papkani kezishni tanlaysiz (odatda uy papkangiz).
- **Kattaligi** — surgichni surib eng kichik hajmni belgilaysiz (100 MB dan boshlab).
- **~/Library ni ham** — belgilasangiz tizim papkasini ham qo'shadi.

Natijalar topilgani sari birma-bir chiqaveradi, hammasini kutib o'tirmaysiz.
Har bir fayl yonida to'liq yo'li, oxirgi o'zgargan vaqti va hajmi ko'rinadi.
Lupa belgisini bossangiz fayl Finder'da ochiladi.

**Yashirin papkalar ham kiradi.** Bu muhim: kompyuterda eng katta fayllar odatda
`~/Documents` da emas, `~/.android` (emulyator obrazlari), `~/.cache`, `~/.docker`
kabi nuqta bilan boshlanadigan papkalarda yotadi. Masalan bu Mac'da Android
emulyatorining `ram.bin` fayllari 4,18 GB + 3,1 GB + 2,09 GB joy egallab turgan edi.

Fayllarni belgilab **Savatga tashlash** ni bosasiz — yana o'sha qoida, hammasi Savatga.

---

## 6. Loyihalar

![Loyihalar](docs/uz-projects.png)

Dasturchi mashinasida eng ko'p joyni `node_modules` va yig'ish fayllari egallaydi.
Bu bo'lim ularni barcha loyihalar bo'ylab topib, loyiha bo'yicha guruhlaydi.

Nimalarni taniydi:

| Papka | Turi | Qanday qaytadi |
| --- | --- | --- |
| `node_modules` | kutubxonalar | `npm install` |
| `dist`, `build`, `out`, `.next`, `.nuxt`, `.turbo`, `coverage` | yig'ish natijasi | `npm run build` |
| `Pods` | CocoaPods | `pod install` |
| `.gradle` | Gradle keshi | `./gradlew build` |
| `target` | Rust/Java | `cargo build` |
| `.venv`, `venv`, `__pycache__` | Python | `pip install -r requirements.txt` |
| `vendor` | PHP/Go | `composer install` |
| `DerivedData` | Xcode | Xcode qayta yig'adi |

**Xavfsizlik qoidasi.** Papka faqat **yonida loyiha belgisi turgan bo'lsa** hisobga
olinadi — ya'ni `package.json`, `Cargo.toml`, `Podfile`, `go.mod` kabi fayl. Shuning
uchun `~/Documents/build` degan oddiy papkangiz hech qachon ro'yxatga tushmaydi.
Topilgan papka ichiga esa umuman kirilmaydi (`node_modules` ichida yana `node_modules`
qidirilmaydi).

**"Faqat 3 oy tegilmaganlari"** belgisini qo'ysangiz, faqat ancha vaqtdan beri
tegilmagan loyihalar qoladi — o'chirishga eng arziydiganlari o'shalar.

Har bir qatorning o'ng tomonida uni qanday qaytarish yozib qo'yilgan, shuning uchun
"o'chirsam nima bo'ladi" deb o'ylab o'tirmaysiz.

---

## 7. O'rnatilgan ilovalar

![O'rnatilgan ilovalar](docs/uz-apps.png)

Kompyuterga o'rnatilgan barcha ilovalar ro'yxati — hajmi, versiyasi bilan.
Pastda umumiy son va umumiy hajm turadi.

Belgilar:

- **Tizim** — macOS bilan birga kelgan ilova, o'chirib bo'lmaydi (qulf belgisi turadi).
- **Ishlayapti** — ayni damda ochiq. O'chirishdan oldin yopish kerak.

**Ilovani butunlay o'chirish.** Ilovani tanlasangiz o'ng tomonda u kompyuterda
qoldirgan barcha fayllar chiqadi:

- `Library/Application Support` — sozlama va ma'lumotlari
- `Library/Caches` — keshi
- `Library/Preferences` — sozlama fayli
- `Library/Containers`, `Group Containers` — konteynerlari
- `Library/Saved Application State` — oxirgi holati
- `Library/HTTPStorages`, `WebKit`, `Logs`, `Cookies`
- `Library/LaunchAgents` — avtomatik ishga tushish fayli

Oddiy usulda ilovani Savatga tashlaganingizda bu fayllar **qolib ketadi** va yillar
davomida joy egallab yotadi. **O'chirish** tugmasi esa ilovaning o'zini ham,
qolgan fayllarini ham birdaniga Savatga tashlaydi.

Har bir faylni alohida belgilash mumkin — masalan ilovani qayta o'rnatmoqchi bo'lsangiz,
sozlamalarini qoldirib ketishingiz mumkin.

---

## 8. Yashirin ilovalar

![Yashirin ilovalar](docs/uz-hidden.png)

Bu ro'yxatga Dock'da ko'rinmaydigan ilovalar tushadi. Ikki xil bo'ladi:

- **Menyu satri** — ekranning yuqori o'ng burchagida ishlaydigan yordamchilar
  (`LSUIElement` belgisi bilan). Masalan Amphetamine, Docker, GoogleUpdater.
- **G'ayrioddiy joy** — `/Applications` dan tashqarida o'rnatilgan ilovalar:
  `~/Library` ichida, Homebrew papkasida yoki yashirin papkalarda.

Nima uchun kerak? Chunki bu ilovalar ko'zga tashlanmaydi. Bu Mac'da masalan
**ikkita Docker** topildi — 4.82.0 va 4.84.0 versiyalari, ikkalasi ham ~2,2 GB.
Biri eskirgan nusxa, oddiy usulda uni hech qachon sezmagan bo'lardingiz.

O'chirish tartibi 4-bo'limdagi bilan bir xil — ilovani tanlaysiz, qoldiqlarini
ko'rasiz, birdaniga Savatga tashlaysiz.

---

## 9. Fonda ishlayotganlar

![Fonda ishlayotganlar](docs/uz-processes.png)

Ayni damda ishlab turgan dasturlar, eng ko'p xotira yeyayotganidan boshlab.
Yuqorida umumiy son va umumiy xotira ko'rinadi.

- **Faqat fondagilar** — belgilangan bo'lsa faqat Dock'da ko'rinmaydigan dasturlarni
  ko'rsatadi. Belgini olsangiz ochiq turgan oddiy ilovalar ham qo'shiladi.
- **Xotira** raqami — Activity Monitor'dagi "Memory" ustuni bilan bir xil
  (`phys_footprint`).
- **Belgilar** — har bir qatorda *O'chirish mumkin / Ortiqcha / Ishlatilmoqda / Tegmang*
  turadi ([2-bo'limga qarang](#2-tavsiya-belgilari)). Port band qilganlarida ustiga
  yashil `5173-port` kabi belgi qo'shiladi.
- **Yopish** — dasturga odatdagidek yopilishni aytadi (ilovalarga `terminate`,
  oddiy jarayonlarga `SIGTERM`). Bu majburiy to'xtatish emas, saqlanmagan ishingiz
  yo'qolmaydi. *Tegmang* belgisi turganda tugma bosilmaydi.

Yuqoridagi rasmda amaliy misol ko'rinib turibdi:

- **Code Helper (Plugin)** — 584 MB, `11294, 59582-port`. VS Code oynasini yopgansiz,
  lekin yordamchisi hamon ishlab turibdi. *Ishlatilmoqda* deb belgilangan, chunki
  portlari ochiq — demak biror narsa unga ulangan bo'lishi mumkin.
- **node** — `5173-port` va `3000-port`. Dev-serverlaringiz. Tegmaslik kerak.
- **npm exec @playwright/mcp** — uchta nusxa, jami ~300 MB, hech qanday porti yo'q,
  ochgan dasturi yopilgan. *Ortiqcha* — yopsangiz bo'ladi.
- **Spotlight, Control Center, loginwindow** — *Tegmang*, tugmasi ham o'chiq.

Bu ekranning foydasi: unutilgan jarayonlarni topish. Masalan bu Mac'da to'rtta
ortib qolgan `npm exec @playwright/mcp` jarayoni bor edi — hammasi bo'lib ~500 MB
xotira, hech kimga kerak emas.

> **Eslatma:** `com.apple.` bilan boshlanadigan tizim jarayonlarini yopmang.
> macOS ularni baribir qayta ishga tushiradi, lekin oraliqda biror narsa
> ishlamay turishi mumkin.

---

## 10. Avtomatik xizmatlar

![Avtomatik xizmatlar](docs/uz-services.png)

macOS o'zi ishga tushiradigan dasturlar — kompyuter yoqilganda yoki tizimga
kirganingizda. Texnik nomi _launch agent_ va _launch daemon_.

Har bir qatorda:

- **Yashil nuqta** — hozir faol. Kulrang — yuklanmagan.
- **Sizniki / Barcha foydalanuvchilar / macOS** — xizmat qayerda turgani.
- **Kirishda ishga tushadi** — `RunAtLoad` belgisi, ya'ni har safar avtomatik ochiladi.
- Pastda — qaysi dasturni ishga tushirishi.

**Nimani o'chirish mumkin:**

| Turi                    | Joyi                      | Holati                                  |
| ----------------------- | ------------------------- | --------------------------------------- |
| Sizniki                 | `~/Library/LaunchAgents`  | **O'chirib, Savatga** tugmasi ishlaydi  |
| Barcha foydalanuvchilar | `/Library/Launch*`        | Qulflangan — administrator paroli kerak |
| macOS                   | `/System/Library/Launch*` | Qulflangan — macOS himoyalagan          |

**O'chirib, Savatga** tugmasi ikki ish qiladi: avval `launchctl bootout` bilan
xizmatni to'xtatadi, keyin uning `.plist` faylini Savatga tashlaydi. Fikringiz
o'zgarsa, faylni Savatdan qaytarib qo'yasiz.

Odatda bu yerda Google Updater, Adobe, Dropbox kabi dasturlarning yangilanish
tekshirgichlari turadi. Ular doim fonda ishlab, batareyani yeydi.

**Apple xizmatlarini ko'rsatish** belgisi — macOS'ning o'z xizmatlarini
(yuzlab) ro'yxatga qo'shadi. Odatda kerak emas, shuning uchun o'chiq turadi.

---

## 11. Xavfsizlik

Fayl o'chiradigan dasturda eng muhimi shu. To'rtta qoida bor:

**1. Hech narsa butunlay o'chirilmaydi.**
Har bir o'chirish `FileManager.trashItem` orqali bo'ladi — bu Finder'dagi
"Savatga tashlash" bilan aynan bir xil amal. Xato qilsangiz qaytarib olasiz.

**2. Har bir yo'l qo'riqchidan o'tadi.**
`SafetyGuard` degan qism har bir faylni o'chirishdan oldin tekshiradi:

- faqat uy papkangiz va `/Applications` ichidagi narsalarga ruxsat;
- `/`, `/System`, `/Library`, `~/Documents`, `~/Desktop`, `~/.ssh`,
  `~/Library/Caches` (papkaning o'zi) — hech qachon o'chirilmaydi;
- eng yuqori darajadagi papkani o'chirish mumkin emas, faqat ichidagi elementlar;
- havola (symlink) orqali ruxsat etilgan joydan chiqib ketishga urinish rad etiladi.

O'zingiz tekshirib ko'rishingiz mumkin:

```bash
./build/MacBroom.app/Contents/MacOS/MacBroom --selftest
```

31 ta tekshiruvni o'tkazadi va natijani ko'rsatadi.

**3. Siz tasdiqlamaguningizcha hech narsa qimirlamaydi.**
Har bir o'chirishdan oldin ro'yxat va umumiy hajm ko'rsatiladi, keyin tasdiqlash
oynasi chiqadi.

**4. Xavfli bo'limlar oldindan belgilanmaydi.**
Zaxira nusxalar va yuklab olingan fayllar _Tekshiring_ deb belgilanadi va
ularni faqat siz qo'lda tanlaysiz.

---

## 12. Terminal rejimi

Dastur oynasiz ham ishlaydi. Bu rejimda **hech narsa o'chirmaydi**, faqat hisobot beradi:

```bash
MacBroom --scan          # o'zbekcha hisobot
MacBroom --scan --lang ru # ru/tr/de/es/fr/zh/en/uz
MacBroom --scan --json   # dastur uchun JSON
MacBroom --map ~         # disk xaritasi, matn ko'rinishida
MacBroom --selftest      # xavfsizlik tekshiruvi
```

Natijasi:

```
  MacBroom — hisobot (hech narsa o'chirilmadi)
  Disk: 245,11 GB dan 120,26 GB band, 124,85 GB bo'sh
  ──────────────────────────────────────────────────────────────────
  Ilovalar keshi              3,72 GB     97 ta       [Xavfsiz]
      · com.openai.codex — 1,48 GB
      · ru.keepcoder.Telegram — 460,4 MB
  Dasturchi keshi             13,76 GB    13 ta       [Xavfsiz]
      · npm cache — 5,93 GB
      · Homebrew downloads — 3,26 GB
  Brauzer keshi               2,14 GB     1 ta        [Xavfsiz]
  ──────────────────────────────────────────────────────────────────
  Bo'shatish mumkin: 19,64 GB
```

---

## 13. Savollar

**Bir marta tozalasam, qancha joy bo'shaydi?**
Bu Mac'da birinchi tekshiruvda 19,6 GB chiqdi. Ko'p qismi dasturchi keshi
(npm 5,9 GB, Homebrew 3,3 GB). Oddiy foydalanuvchida kamroq, lekin brauzer
keshi va loglar baribir bir necha GB bo'ladi.

**Kesh o'chirilsa biror narsa buziladimi?**
Yo'q. Kesh — bu ilova tezroq ishlashi uchun saqlab qo'ygan nusxa. O'chirilsa
ilova uni qaytadan yaratadi, faqat birinchi ochilish biroz sekinroq bo'ladi.

**Qanchalik tez-tez ishlatish kerak?**
Oyiga bir marta yetadi. Dasturchi bo'lsangiz, loyihalar bilan ko'p ishlasangiz
ikki haftada bir marta.

**Savatni ham o'zi tozalaydimi?**
Yo'q, ataylab. Savatni tozalash — orqaga qaytarib bo'lmaydigan amal, shuning uchun
uni Finder orqali o'zingiz qilasiz. MacBroom Savatdagi fayllarni faqat ro'yxatda
ko'rsatadi, hajmini bilishingiz uchun.

**Internetga chiqadimi, ma'lumot yuboradimi?**
Yo'q. Dasturda tarmoq kodi umuman yo'q. Tashqi kutubxona ham ishlatilmaydi.

**Nega Downloads papkasini ko'rmoqchi bo'lganda ruxsat so'raydi?**
macOS `~/Downloads`, `~/Desktop`, `~/Documents` papkalarini himoyalaydi. Ruxsat
bermasangiz dastur o'sha papkalarni shunchaki o'tkazib yuboradi, ishlashda
boshqa muammo bo'lmaydi.

**Yangi tozalash joyi qo'shsam bo'ladimi?**
Ha. `Sources/MacBroom/Core/ScanCatalog.swift` faylidagi `rules` ro'yxatiga
bitta qator qo'shasiz:

```swift
.init(category: .devCaches, path: h("Library/Caches/MyTool"), mode: .itself, label: "MyTool keshi"),
```

Keyin `./Scripts/build_app.sh release` bilan qayta yig'asiz.
