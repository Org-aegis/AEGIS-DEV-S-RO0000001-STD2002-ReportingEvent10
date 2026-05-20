# シンプルなテキスト処理パッケージをロード
library(glue)

output_path <- "result.txt"

# システム日付を「YYYY/MM/DD HH:MM:SS」形式の文字列にする
current_time <- format(Sys.time(), "%Y/%m/%d %H:%M:%S")

# glueでテキストを作成
formatted_text <- glue("{current_time}")

# コンソールに画面表示（echo）し、ファイルへ出力する
print(formatted_text)
writeLines(formatted_text, con = output_path)