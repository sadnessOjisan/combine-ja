---
title: Home
original_url: https://github.com/Marwes/combine/wiki
---

## combine とは何か

`combine` はパーサーコンビネータライブラリです。

パーサーは入力を分割し(例えば `&str` or `&[u8]`)、何らかの出力(例えば `(i32, Vec<i32>)`)に変換するアルゴリズムです。

コンビネーターは、複数の小さなパーサーを組み合わせてより大きなパーサーを作る機能のことです。`combine` では 1 つまたは複数のパーサーを引数として受け取り、新しいパーサーを返す関数を定義して呼び出すことで実現できます。例えば次の通りです。

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

Listing A-1 - 'Hello combine' example

`take_while1`、`range`、`sep_by`は`combine`ライブラリのパーサーコンビネータです。`tool`と`tools` はそれらのコンビネータから生成されたパーサーです。tools は作られた最終的なパーサーでもあります。

## チュートリアル

詳しくは [Quickstart Tutorial](Tutorial) で学べます。

## Inner machinery

様々な言語で実装される様々なパーサーには次の 4 つを必要とします。

- [解析するデータまたはそのデータの取得方法](Input-Machinery)
- [パースする形式の定義](Parser-Trait)
- 見つけた情報を集めて返す方法
- [パース中のエラーを通知する方法](Error-Handling)

また、次の追加機能のサポートも必要とするでしょう。

- 入力データのパース／ストリーミングの再開
- 入力データトークンの位置情報の付与（テキスト入力の場合は行や列など）

`compine` は入力として使用できるものに対して可能な限り柔軟であろうとするので、実装すべきトレイトは非常に多くなりますが、アプリケーションレベルで使用する場合は、それらのうちのいくつか (`Stream`、`RangeStream`および`FullRangeStream`, 後者 2 つは zero-copy のパースをする場合のみ) を気にすればよいです。

リンク先の章ではこれらのことに対する `combine`流を説明し、なぜそのようになるのかを説明します。これは、エラーメッセージの理解に大いに役立ち出会ってもひるまなくなるでしょう。

## 代替になるライブラリ

Rust エコシステムにはこの手のライブラリに他の選択肢があります。

- [nom](https://crates.io/crates/nom)
- [pest](https://crates.io/crates/pest)
- [lalrpop](https://crates.io/crates/lalrpop)

それぞれトレードオフがあります。賢く選定しましょう :smile:
