# App Store 提出の準備

> 名前・説明・キーワードなどの正本は `docs/app-store.json`（`.github/workflows/asc.yml` の metadata が App Store Connect に API で入れる）。ここは審査の危険と、本人がすることの記録。

| 項目 | 内容 |
|---|---|
| Bundle ID | com.enludus.daily.013 |
| アプリ名 | うおさがし / Ripple Pond（App Store 名：うおさがし：数を読んで魚を釣るパズル / Ripple Pond: Logic Fishing）（AI が決めた。本人の許可 2026-11-04） |
| サポート URL | https://github.com/enludus-daily/app-20261118-uosagashi/issues |
| プライバシーポリシー URL | https://github.com/enludus-daily/app-20261118-uosagashi/blob/main/PRIVACY.md |
| 年齢区分の答え | すべて「なし」の想定（暴力なし・ギャンブルなし〔賭け・お金のやりとりなし〕・Web 閲覧なし・生成 AI なし・ユーザー間のやりとりなし）→ 4+。本人が入力 |
| 輸出コンプライアンス | `ITSAppUsesNonExemptEncryption = NO`（標準の暗号だけ。ビルドの答えは asc が NO で入れる） |

## 審査の危険

- 4.3(b) の種類に当たらない理由：推理パズルと釣り（図鑑・大きさの記録）の組み合わせのゲーム。懐中電灯・占い・単純なタイマーなどではない
- 既存のアプリとの意味のある違い：App Store のマインスイーパーは地雷を避けて 1 回のミスで終わる形ばかり。ここは魚を「釣る」操作があり、外しても糸が減るだけ・ぬし（2 匹ぶん）や群れや氷で数え方が変わる・釣った魚が図鑑と大きさの記録になる。盤は推理だけで解けることを確かめて出す
- 長く使える価値（4.2）：今日の池（毎日同じ種）・釣り場 4 つ × 20 池・魚図鑑 20 種と大きさの記録・続けた日数
- 他社の名前・商標・見た目を使っていないか：「マインスイーパー（Minesweeper）」の名前はアプリ名・サブタイトルに使わない（説明文でも使わない）。絵・魚・アイコンは自作の図形
- Apple Intelligence を使う場合、使えない端末での動き：使わない
- 通知：今日の池の知らせ（設定でオンにしたときだけ許可を求める。端末の中の予定通知で、通信しない）

## 収益の道筋（本人が選ぶ）

- 買い切り Pro ¥480（StoreKit 2。`com.enludus.daily.013.pro`。asc.yml の products で作る）
- 理由と勝算の表：README の「課金」

## App プライバシーの答え（下書き。申告は本人。公開 API がない）

- データの収集：**なし**（根拠：通信しない、解析・広告 SDK なし、保存は端末の UserDefaults だけ）
- トラッキング：なし
- Privacy manifest：`App/Resources/PrivacyInfo.xcprivacy`（UserDefaults: CA92.1）

## スクリーンショット

CI の artifact `screenshots`（iPhone Duo のシミュレータ）。足りない画面は本人と相談。

## 本人がすること

- [ ] App プライバシーを申告する（API がない）
- [ ] 年齢区分を答える
- [ ] TestFlight で動作を確かめる（内部テストのグループ `daily-internal` に自動で配信される）
- [ ] スクリーンショットを確かめる
- [ ] 審査に提出する
