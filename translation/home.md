---
title: Home
original_url: https://github.com/Marwes/combine/wiki
---

## combine とは何か

> `combine` is a parser combinator library. Let's explain that in two steps.

`combine` はパーサーコンビネータライブラリです。概要を 2 ステップで説明します。

> A "parser" is an algorithm that turns a string of input (for example a `&str` or `&[u8]`) into some output (for example `(i32, Vec<i32>)`) according to a grammar.

パーサーは入力を分割し(例えば `&str` or `&[u8]`)、何らかの出力(例えば `(i32, Vec<i32>)`)に変換するアルゴリズムです。

> A "combinator" refers to the ability to _combine_ multiple smaller parsers into a larger one. In `combine` this is done simply by defining and calling functions which take one or more parsers as arguments and returns a new parser. This is how it looks like:

コンビネーターは、複数の小さなパーサーを組み合わせて、より大きなパーサーを作る機能のことです。`combine` では、1 つまたは複数のパーサーを引数として受け取り、新しいパーサーを返す関数を定義して呼び出すだけで、これを行うことができます。次の通りです。

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

> `take_while1`, `range` and `sep_by` are parser combinators from the `combine` library. `tool` and `tools` are parsers produced from those combinators. The latter is also the final parser.

`take_while1`、`range`、`sep_by`は`combine`ライブラリのパーサーコンビネータです。`tool`と`tools` はそれらのコンビネータから生成されたパーサーです。tools は作られた最終的なパーサーでもあります。

## チュートリアル

> Learn `combine` with the not so quick [Quickstart Tutorial](Tutorial).

詳しくは [Quickstart Tutorial](Tutorial) で学べます。

## Inner machinery

> Every parser in every language needs roughly these four things to work:

様々な言語で実装される様々なパーサーにはこれら 4 つのことを必要とします。

> - [The data to parse or a way to obtain that data](Input-Machinery)
> - [A definition of the format to parse](Parser-Trait)
> - A way of gathering and returning the information it has found
> - [A way to notify about Errors during parsing](Error-Handling)

- [解析するデータまたはそのデータの取得方法](Input-Machinery)
- [パースする形式の定義](Parser-Trait)
- 見つけた情報を集めて返す方法
- [パース中のエラーを通知する方法](Error-Handling)

> It may also support one or more of these extra functionalities

また、これらの追加機能のサポートもあるでしょう。

> - Resume parsing / streaming of input data
> - Giving location information of input data tokens (e.g. line, column for text input)

- 入力データのパース／ストリーミングの再開
- 入力データトークンの位置情報の付与（テキスト入力の場合は行や列など）

> As `combine` attempts to be as flexible as possible in what can be used as input there can be quite a few traits to implement but most of the high-level use should only need to concern itself with a few of them (namely `Stream`, `RangeStream` and `FullRangeStream`, the latter two only for zero-copy parsing).

`compine` は入力として使用できるものに対して可能な限り柔軟であろうとするので、実装すべきトレイトは非常に多くなりますが、アプリケーションレベルで使用する場合は、それらのうちのいくつか (`Stream`、`RangeStream`および`FullRangeStream`, 後者 2 つは zero-copy のパースをする場合のみ) を気にすればよいのです。

> The linked chapters describe the `combine` way of these things and why they are the way they are. This helps a lot understanding error messages and dealing with sticks and stones.

リンク先の章ではこれらのことに対する `combine`流を説明し、なぜそのようになるのかを説明します。これは、エラーメッセージの理解に大いに役立ち、出会ってもひるまなくなるでしょう。

## 代替になるライブラリ

> For reference, here are some alternatives in the rust ecosystem:

Rust エコシステムにはこの手のライブラリに他の選択肢があります。

- [nom](https://crates.io/crates/nom)
- [pest](https://crates.io/crates/pest)
- [lalrpop](https://crates.io/crates/lalrpop)

> All parser libraries come with their own trade offs, so choose wisely :smile: .

それぞれトレードオフがあります。賢く選定しましょう :smile:
