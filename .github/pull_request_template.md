## PR タイトル(必須)
<!-- 下記のフォーマットに合わせて修正し、PRのタイトル（Subject）として使用してください -->

merge([source]->[target]): [summary]

## 今回の更新内容（レビュー者向けに必要なら記載）

- 機能の改善内容
- 不具合修正内容
- 注意事項

## 参考情報

<details>

<summary>📌 PR タイトル規約</summary>
<br>

**フォーマット**

```
merge([source]->[target]): [summary]
```

**例**

```
merge(dev->qa): auth OAuth ログイン追加
merge(qa->main): release 1.4.0
merge(feature/login-timeout->dev): ログインタイムアウト修正
```

**補足ルール**

- PR タイトルは Merge Commit の先頭行として使用されます
- 規約に一致しない PR は GitHub Actions によりマージ不可となります
- summary は日本語 / 英語どちらでも可

</details>

<details>

<summary>📌 リリースラベルについて（この PR のマージ先が <b>main</b> の場合のみ必須）</summary>
<br>

`main` にマージする前に、以下のいずれか **1 つだけ** のラベルを付与してください。

- `release:major`  
  互換性のない変更・大きな仕様変更を含む場合
- `release:minor`  
  後方互換性のある機能追加・改善の場合
- `release:patch`  
  バグ修正や小さな修正のみの場合
- `no-release`  
  配信（リリース）不要な変更の場合  
  （例：ドキュメント更新、CI 設定変更など）

※ `dev` や `qa` へのマージの場合は対応不要です。

</details>
