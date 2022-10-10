
## combine とは何か

`combine` はパーサーコンビネータライブラリです。2つのステップで説明しましょう。

パーサーは文法に従って入力を分割し（例えば `&str` or `&[u8]`）、何らかの出力（例えば `(i32, Vec<i32>)`）に変換するアルゴリズムです。

「コンビネーター」は、複数の小さなパーサーを組み合わせてより大きなパーサーを作る機能のことです。`combine`
では1つ以上のパーサーを引数として受け取り、新しいパーサーを返す関数を定義して呼び出すことで実現できます。例えば次の通りです。

```rust
# use combine::parser::range::{range, take_while1};
# use combine::parser::repeat::{sep_by};
# use combine::parser::Parser;

let input = "Hammer, Saw, Drill";

// a sequence of alphabetic characters
let tool = take_while1(|c : char| c.is_alphabetic());

// many `tool`s, separated by ", "
let mut tools = sep_by(tool, range(", "));

let output : Vec<&str> = tools.easy_parse(input).unwrap().0;
// vec!["Hammer", "Saw", "Drill"]
```
*Listing A-1 - 'Hello combine' example*

`take_while1`、`range`、`sep_by`は`combine`ライブラリのパーサーコンビネータです。`tool`と`tools`
はそれらのコンビネータから生成されたパーサーです。tools は作られた最終的なパーサーでもあります。

## チュートリアル

それほど手軽にはいきませんが[クイックスタートチュートリアル](Tutorial)で`combine`を学べます。

## 内部の仕組み

あらゆる言語のあらゆるパーサーには大まかに言ってこれら4つが動作することが必要です。

- [パースするデータまたはそのデータの取得方法](Input-Machinery)
- [パースする形式の定義](Parser-Trait)
- 見つけた情報を集めて返す方法
- [パース中のエラーを通知する方法](Error-Handling)

1つ以上の追加の機能に対応することもあります。

- 入力データのパース／ストリーミングの再開
- 入力データトークンの位置情報の付与（テキスト入力の場合は行や列など）

`compine` は入力として使用できるものに対して可能な限り柔軟であろうとするので、実装すべきトレイトは非常に多くなりますが、アプリケーションレベル
(high-level) で使用する場合は、それらのうちのいくつか
(`Stream`、`RangeStream`および`FullRangeStream`, 後者2つは zero-copy のパースをする場合のみ)
を気にすればよいです。

リンク先の章ではこれらのことに対する
`combine`の流儀を説明し、なぜそのようになっているのかを説明します。これは、エラーメッセージの理解に大いに役立ち、出会ってもひるまなくなるでしょう。

## 代替になるライブラリ

参考のために、Rust エコシステムには他の選択肢があります。

 - [nom](https://crates.io/crates/nom)
 - [pest](https://crates.io/crates/pest)
 - [lalrpop](https://crates.io/crates/lalrpop)

全てのパーサライブラリにはそれぞれトレードオフがあります。賢く選定しましょう :smile:
