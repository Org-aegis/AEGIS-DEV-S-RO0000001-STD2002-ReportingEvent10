# 1. シンプルなテキスト処理パッケージをロード
library(glue)

# 2. カレントフォルダの2つ上の層にある「prod/output/result.txt」のパスを作成
output_dir <- file.path("..", "..", "prod", "output")
output_path <- file.path(output_dir, "result.txt")

# 3. システム日付を「YYYY/MM/DD HH:MM:SS」形式の文字列にする
current_time <- format(Sys.time(), "%Y/%m/%d %H:%M:%S")

# 4. glueでテキストを作成
formatted_text <- glue("{current_time}")

# 5. コンソールに画面表示（echo）し、ファイルへ出力する
print(formatted_text)
writeLines(formatted_text, con = output_path)