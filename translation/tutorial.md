---
title: Tutorial
original_url: https://github.com/Marwes/combine/wiki/Tutorial
---

## コードの構成

> `combine` is very flexible in regards to its data source and error handling but for the sake of keeping this tutorial simple I will assume that your input is `&str` and that you want extended error information. If you need another input source or want to customize the errors used, see the chapter "Inner Machinery" for all the options.

`combine` はデータソースとエラーハンドリングの観点でとても柔軟なライブラリですが、このチュートリアルをシンプルなものにするためにインプットを `&str` としすでに拡張されたエラーを使うと仮定します。もし他の入力ソースが必要な場合や、使用するエラーをカスタマイズしたい場合は、すべてのオプションについて "Inner Machinery" の章を参照してください。

> Let's start by structuring your parsing code correctly from the beginning.
> The 'Hello combine' example works, but only because it only uses the each parser once. To make it re-usable and testable we package it into a function. We also add the `decode()` function to make handle some organizational stuff like transforming the error type.

まずは、パースするコードを最初から正しく構成することを始めましょう。
'Hello combine'の例はうまくいきますが、それは各パーサーを一度しか使っていないからです。
それを再利用やテストができるように、これを関数としてまとめます。
また、`decode()` 関数を追加してエラータイプの変換などの処理を行うようにします。

> The code otherwise does the same parsing as 'Hello combine' example in listing A-1 from the first chapter. Errors are returned as String here, in your own code you would likely have your own error type instead. The only real difference is, that I wrapped the input with a [`State`](https://docs.rs/combine/*/combine/stream/state/struct.State.html) which adds line and column information to the parser errors.

それ以外のコードは、第 1 章のリスト A-1 にある 'Hello combine' の例と同じパース処理を行います。
ここではエラーを String で返しますが、あなたのコードでは独自のエラータイプを使っているかもしれません。
唯一の違いは入力を [`State`] (https://docs.rs/combine/*/combine/stream/state/struct.State.html) でラップして、パーサーエラーに行と列の情報を追加していることです。

```rust
# use combine::parser::range::{range, take_while1};
# use combine::parser::repeat::{sep_by};
# use combine::parser::Parser;
# use combine::stream::{RangeStream, state::State};
# use combine::error::ParseError;
#
// Copy the fn header as is, only change ------------╮
//                                                   v
fn tools<'a, I>() -> impl Parser<I, Output = Vec<&'a str>>
    where I: RangeStream<Token = char, Range=&'a str>,
          I::Error: ParseError<I::Token, I::Range, I::Position>,
{
    let tool = take_while1(|c : char| c.is_alphabetic());
    sep_by(tool, range(", "))
}

fn decode(input : &str) -> Result<Vec<&str>, String> {
    match tools().easy_parse(State::new(input)) {
        Ok((output, _remaining_input)) => Ok(output),
        Err(err) => Err(format!("{} in `{}`", err, input)),
    }
}

let input = "Hammer, Saw, Drill";
let output = decode(input).unwrap();
```

Listing T-1 - 'Hello combine' example, extended

> Any parser that we want to use more than once must be defined in the form `fn xyz() -> impl Parser`, like `tools` in the above example. To use such a parser, you must call the function instead of using it like a variable: `tools()` in listing T-1 vs `tools` in listing A-1.

複数回使用したいパーサーは、上の例の `tools` のように `fn xyz() -> impl Parser` という形で定義する必要があります。このようなパーサーを使用するには、変数のように使用するのではなく、関数を呼び出す必要があります。リスト T-1 の `tools()` とリスト A-1 の `tools` を比較してみてください。

> Whenever you create new `fn` parsers, just copy the whole `fn` header from this example, including the `where` clause. Change the function name and adapt the `Output` type. The `I::Error` line is noisy, but unfortunately necessary due to [rust-lang/rust#24159][]. If that is too noisy for you, see chapter TODO.

新しい `fn` パーサーを作成するときは、この例から `where` 節を含む `fn` ヘッダーを丸ごとコピーすればよいです。関数名を変更し、 `Output` 型も合わせます。`I::Error` の行はごちゃごちゃしていますが、残念ながら [rust-lang/rust#24159][] のために必要です。もしこれがうるさいようであれば TODO の章を参照してください。

[rust-lang/rust#24159]: https://github.com/rust-lang/rust/issues/24159

## パース

> Parsing starts at the beginning of the input. The parser then goes forward character by character, deciding what to do next on every step. It can go back a few steps and try something else if it hit a dead end in its logic. It can decide its decoding path on data it has seen previously.

パースは入力の先頭から始まります。そして、パーサーは一文字ずつ進めていき、その都度次に何をすべきかを決定していきます。パース中に行き詰まりると、数ステップ戻って別のパースを試みることもできます。また以前に読み取ったデータに基づいて、パースする経路も決められます。

> Each parser returns some output value which is assembled from the processed characters and/or the output of nested parsers. A parser can alternatively return an error condition if the input did not match its expectations.

各パーサーは、以前の処理した字句、またはネストされたパーサーから構成された戻り値を返します。パーサーは予想した値と入力が一致しない場合、代わりにエラー条件を返せます。

> For all primitive parsers like `digit()` applies: If a parser read and processed some bytes from the input stream, the bytes are consumed and subsequent parsers start where the previous one finished (however there are some special combinators which break this rule).

`digit()`のようなすべてのプリミティブなパーサーには次のことが適用される話ですが、もしパーサーが入力ストリームからいくつかの byte を読み取り処理した場合、その byte は消費され後続のパーサーは前のパーサーが終了したところから始まります（ただし、このルールを破る特別なコンビネータもいくつかあります）。

## 出力の型を理解する

> To write parsers effectively, you must understand what happens with the output values.

パーサーを効率的に書くためには、値の出力が何かを理解しなければいけません。

> At the end, there is only a single output type/value. This type/value must contain all the information you want to extract.

結論としては、1 つの出力の型/値だけが存在します。この型/値には、抽出したい情報がすべて含まなければいけません。

> During the parsing process, new outputs arise, some outputs are `map()`ped to different types, some are merged and some are dropped. Fortunately, there is an expressive toolset to manage this.

パースの過程では、新しい出力が発生し、ある出力は `map()`され、ある出力はマージされ、ある出力は削除されます。幸いなことにこれを扱うための表現力豊かなツールセットが存在します。

> Let's first look at a parser that has no nested parsers: `parser::char::digit`. This parser has the output type `char` and consumes one character of the input stream. The output value will be the consumed character. It errors if the consumed character is no digit (0-9).

まず、ネストがないパーサーとして `parser::char::digit` を見てみましょう。このパーサーは出力タイプに `char` を持ち、入力ストリームを 1 文字消費します。出力値は、消費された文字になります。消費された文字が数字(0-9)でない場合は、エラーになります。

> The most basic combination of parsers is sequencing and the simplest way this can be done by putting them in a tuples. The output of that tuple parser is also a tuple.

パーサーの最も基本的な組み合わせ方法は連続であり、これを最も単純に行う方法はタプルに入れることです。タプルパーサーの出力はタプルです。

```rust
let two_digits = (digit(), digit()); // Output = (char, char)
```

> Only chaining parsers using tuples would make the output type very complicated very soon as the output would be an equally large tuple. Fortunately, we have several options to remedy this:

タプルを使ってパーサーを連結するだけでは、出力が同じように大きなタプルになるため、すぐに出力型が非常に複雑になります。幸いなことに、これを解決するためのいくつかの選択肢があります。

> - Drop (unneeded) parts of the output type by mapping or processing it: `let first_digit = (digit(), digit()).map(|(digit1, _digit2)| digit1);` Note: There are often more expressive helpers like [`skip`][] or [`with`][]: `let first_digit = digit().skip(digit());`
> - Collect repeating elements into a `Vec` or similar.
> - Ignoring a complicated output type and instead taking a `&str` slice of what has been consumed: `let two_digits_str = recognize( (digit(), digit()) );`
> - Assemble your (complex/recursive) output type, for example `json::Value`.

- 出力された型をマッピングまたは加工することで、(不要な)部分を削除する。(例): `let first_digit = (digit(), digit()).map(|(digit1, _digit2)| digit1);` (注意)：[`skip`][] や [`with`][] など、より表現力のあるヘルパーもあります： `let first_digit = digit().skip(digit());`
- 繰り返しの要素を `Vec` などにまとめる。
- 複雑な出力型を無視し、代わりに消費された `&str` スライスを取得する。`let two_digits_str = recognize( (digit(), digit()) );`
- (複雑な/再帰的な)出力タイプを組み立てる、例えば `json::Value` など。

> But there is no fits-all strategy, it all depends on your parsing problem.

しかし、万能の戦略はなく、全てはあなたがパースしたいものに依存します。

[`parser::char::digit`]: https://docs.rs/combine/*/combine/parser/char/fn.digit.html
[`with`]: https://docs.rs/combine/*/combine/trait.Parser.html#method.with
[`skip`]: https://docs.rs/combine/*/combine/trait.Parser.html#method.skip

## パースしたいものの課題を理解する

> Research your parsing problem. Make sure you really understand what you want to parse. If, for example you want to parse a JPEG header:

> - Is there an official specification?
> - Does the real world follow the specification? (often not 100%)
> - Search for other resources like blog posts, they may contain helpful clues.
> - Gather examples from different sources, and include them in you tests to catch problems early on.

あなたのパースに関する課題を研究しましょう。何をパースしたいのかを本当に理解しているか確認してください。例えば、あなたが JPEG のヘッダーを解析したい場合、

- 公式の仕様は存在していますか？
- 現実の実装はその仕様に則っていますか？(100%ではない場合が多い)
- ブログ記事など、他のリソースを検索してみると、役に立つヒントがあるかもしれません。
- 様々な異なる情報源から例を集め、テストに含めることで、問題を早期に発見できます。

## 出力したいものをスケッチする

> Sketch the type structure that the parser should ideally return. Decide if the parser output needs to be owned (`String`, ...) or if you want to exercise zero-copy so the output references parts of the input (`&str`, ...).

パーサーが理想的に返すべき型構造をスケッチしよう。パーサーが、所有権を持つようなものを出力すべきか (`String`, ...) あるいは、出力が入力の一部を参照するようにゼロコピーを実行したいのか (`&str`, ...) を決めます。

## 例から学ぶ

> That was a lot of information, but you have not yet any clue on how to write parsers yet? Let's go step by step by showing little examples and explain what common problem they solve.

いろいろ情報がありましたが、まだパーサーの書き方について何の手がかりもないのではありませんか？それでは、少しずつ例を挙げながら、どのような問題を解決するのかを説明していきましょう。

> All parsers and combinators live in the `parser` module, even if some of them are reexported to the main module. In the following chapters, we assume `use combine::parser::*;`

たとえその一部がメインモジュールに再エクスポートされたとしても、すべてのパーサーとコンビネーターは `parser` モジュールにあります。以下の章では、 `use combine::parser::*;` を使うことを前提にします。

> (Most examples use the [`char`][] module, if you are parsing bytes and not strings there is often an equivalent function in the [`byte`][] module.)

ほとんどの例では [`char`][] モジュールを使用しますが、文字列ではなくバイトをパースする場合は、[`byte`][] モジュールに同等の関数があるのでそれを使用できます。

[`char`]: https://docs.rs/combine/*/combine/parser/char/index.html
[`byte`]: https://docs.rs/combine/*/combine/parser/byte/index.html

### 定型の文字列をパースする

> Often, a format contains some constant parts. You need to check for their existence, but they don't matter for the parsers output.

多くの場合、フォーマットはいくつかの定数部分を含んでいます。それらの存在を確認する必要がありますが、パーサーの出力には関係ありません。

> Use [`char::char('x')`][char::char] for characters and [`char::string("abcde")`][char::string] (or [`range::range("abcde")`][range::range] if zero-copy) for slices. The output type of these parsers is `char` and `&str` respectively.

文字には [`char::char('x')`][char::char] を、スライスには [`char::string("abcde")`][char::string] (0-copy なら [`range::range("abcde")`][range::range]) を用います。これらのパーサーの出力型は、それぞれ `char` と `&str` です。

[char::char]: https://docs.rs/combine/*/combine/parser/char/fn.char.html
[char::string]: https://docs.rs/combine/*/combine/parser/char/fn.string.html
[range::range]: https://docs.rs/combine/*/combine/parser/range/fn.range.html

### 空白文字などの文字クラスをパースします。

> Human readable formats like JSON ignore whitespace (spaces, tabs, newlines). [`char::space`][] parses all whitespace characters according to the unicode White_Space category. Look into the `parser::char` module for more predefined character classes.

JSON のような人間が読める形式では、空白文字（スペース、タブ、改行）は無視されます。[char::space`][] は、ユニコードの White_Space カテゴリに従って、すべてのホワイトスペースをパースします。その他の定義済み文字クラスについては、 `parser::char` モジュールを参照してください。

> Use [`item::satisfy`][] to define your own character classes. For example `item::satisfy(|c| c != '\n')` parses everything except a newline. (You may not that this is in the [`item`][] module which means it works regardless of the input type).

独自の文字クラスを定義するには [`item::satisfy`][] を使用します。例えば `item::satisfy(|c| c != '\n')` は改行以外のすべてをパースします。(これは [`item`][] モジュールの中にあるので、入力のタイプに関係なく動作することを意味します）。

The output of each of these parsers is the `char` they have matched.

このパーサーの出力は、それぞれがマッチさせた `char` です。

[`char::space`]: https://docs.rs/combine/*/combine/parser/char/fn.space.html
[`item::satisfy`]: https://docs.rs/combine/*/combine/parser/item/fn.satisfy.html
[`item`]: https://docs.rs/combine/*/combine/parser/item/index.html

### 連続した空白または単語を解析する

> All the above parsers match just a single letter. Sometimes we want to parse words or consecutive whitespace. This can be done by using the parser combinators from [`repeat`][].

上記のパーサーはすべて 1 文字にのみマッチします。時には、単語や連続した空白を解析したいこともあります。これは [`repeat`][] のパーサコンビネータを使用することで実現できます。

> If you want to ignore the matched characters, you can use `repeat::skip_*` functions:

マッチした文字を無視したい場合は、 `repeat::skip_*` 関数を使用できます。

- `skip_many(space())` - 0 or more whitespace characters (same as `char::spaces()`)
- `skip_many1(space())` - 1 or more whitespace characters
- `skip_count(4, space())` - exactly 4 whitespace characters
- `skip_count_min_max(1, 4, space())` - 1 to 4 whitespace characters
- `skip_until(item::satisfy(|c| c != '\n'))` - everything until the end of line

> The `skip_*` combinators have the output type `()`, but they nonetheless consume from the input stream.

`skip_*` コンビネータは出力型に`()`を持ちますが、それにもかかわらず入力ストリームから消費されます。

> On the other hand, if you want to have the consumed slice as output, things are more complicated. [`repeat::many`][] works and can easily be used to collect into a `String`, `Vec` or any other type that implements `Extend`. However, for collecting single characters it may not be performant enough.

一方、消費されたスライスを出力にしたい場合は、より複雑になります。そのためには[repeat::many`][] はで実現でき、 `String` や `Vec` などの `Extend` を実装している型に簡単に取り込むことができます。しかし、1 文字を収集するためには、十分なパフォーマンスを発揮できないかもしれません。

> Thus there are some additional alternatives, depending on how you can describe the characters to consume.

このように、あなたがどのように文字を消費できるかによって、いくつかの選択肢が追加されます。

> - `range::recognize(repeat::skip_many1(char::letter()))` - Use this if you want to describe the range of interest as a combination of other parsers. Because the output of the inner parsers doesn't matter, you can use the `skip_*` combinators. [`range::recognize`][] will then look at what has been consumed by its inner parser(s) and use that range/slice as its output.
> - `range::take_while1(|c| c.is_alphabetic())` - Here you can inspect characters using a closure. Similar to `skip_until(item::satisfy(..))` (but inverse logic).
> - `range::take_until_range(">>>")` - Wait for a constant and return everything that has been consumed before that constant occurred.

- `range::recognize(repeat::skip_many1(char::letter()))`. 対象の範囲を他のパーサーと組み合わせて記述したい場合に利用します。内部のパーサーの出力は重要ではないので、 `skip_*` コンビネーターが使用できます。[range::recognize`][] は内部のパーサーによって消費されたものを見て、その範囲やスライスを出力として使用します。
- `range::take_while1(|c| c.is_alphabetic())`. クロージャを使用して文字を検査することができます。`skip_until(item::satisfy(...))` に似ています（ただし反対のロジックです）。
- `range::take_until_range(">>")` - 定数値を待ち、その定数値に出会う前に消費されたものを全て返します。

> These parsers and more like them all exist in the [`range`][] module which contains parsers specialized to zero-copy input such as `[u8]` and `str`, if you have a different input you may need to make do with [`repeat::many`][]

これらのパーサーや似たようなものは全て [`range`][] モジュールに含まれています。このモジュールには `[u8]` や `str` といったゼロコピー入力に特化したパーサーが含まれており、もし別の入力を想定しているのならば [`repeat::many`][] を使ってください。。

[`repeat`]: https://docs.rs/combine/*/combine/parser/repeat/index.html
[`repeat::many`]: https://docs.rs/combine/*/combine/parser/repeat/fn.many.html
[`range::recognize`]: https://docs.rs/combine/*/combine/parser/range/fn.recognize.html
[`range`]: https://docs.rs/combine/*/combine/parser/range/index.html

### 出力の変換

> At any time, you can manipulate the output value. You can for example drop some parts of it or parse a `&str` made of digits to an `u32`.

いつでも、出力値を操作できます。例えば、ある部分を削除したり、数字で構成された `&str` を `u32` にパースできます。

> The relevant functions are part of the [`Parser`][] trait, so you use the `.` notation: `digit().map(|d| d)`.

関連する関数は [`Parser`][] trait に含まれているので、 `.` 記法を使用します: `digit().map(|d| d)`.

```rust
    fn map<>(self, f: impl FnMut(O) -> B) -> impl Parser<Output = B> {}
    fn and_then<>(self, f: impl FnMut(O) -> Result<B, S_ERR>) -> impl Parser<Output = B> {}
    fn flat_map<>(self, f: impl FnMut(O) -> Result<B, P_ERR>) -> impl Parser<Output = B> {}
```

> The return value of these three functions is a parser again. This is similar to calling `map()` on an `std::iter::Iterator`, which returns an `impl Iterator` again. Like `Iterator`, after combining all the parsers, you have not parsed anything yet, just created an instance of a type that is able to parse your input. Just like iterating starts when calling `next()`, parsing starts when calling `parse*()`.

これら 3 つの関数の戻り値は、再びパーサーとなります。これは、 `std::iter::Iterator` に対して `map()` を呼び出すと、再び `impl Iterator` が返されるのと似ています。`Iterator`と同様に、すべてのパーサーを結合した後は、まだ何もパースしておらず、入力をパースすることができる型のインスタンスを作成しただけになります。イテレートが`next()`を呼び出したときに始まるように、パースも`parse\*()` を呼び出したときに開始されます。

> What is the difference between these functions and when to use them?

これらの機能の違いはなにか、どのような場合に使うのか。

- `map()` allows you to map the output to another type. For example you can convert a `&str` to a `String`, or move some values from tuple form into a custom struct. The closure is not able to return an error.
  - `(a(), b()).map(|(a, b)| MyType { a: a, b: b} )`
  - `recognize(skip_many1(letter())).map(|s| s.to_string())`
- `and_then()` is the most capable of the three functions. In contrast to `map()`, the closure returns a `Result<>`. Use this if your transformation may fail, for example if you want to parse some digits into a numeric type.
  - `recognize(skip_many1(digit())).and_then(|digits : &str| digits.parse::<u32>().map_err(StreamErrorFor::<I>::other) )` (This could also be written with [`from_str(recognize(skip_many1(digit())))`][`from_str`])
  - You can use any constructor of the `error::StreamError` trait to create an error. The most helpful constructors are:
    - `StreamErrorFor::<I>::other(some_std_error)`
    - `StreamErrorFor::<I>::message_message(format!("{}", xyz))`
    - `StreamErrorFor::<I>::message_static_message("Not supported")`
- `flat_map()` is very similar to `and_then()`, but they differ in the error type the closure must return. Use `flat_map()` if you want to parse some output in more detail with another parser. (see its documentation)

  - `and_then()` takes an `error::StreamError` where as `flat_map()` takes an `error::ParseError`.
  - `and_then()` will add position information to the error automatically, for `flat_map()` you have to take care of that yourself. You may need to transform the position information.

- `map()` は、出力を別の型にマップすることができます。例えば、 `&str` を `String` に変換したり、タプル型からカスタム構造体に値を移動させたりすることができます。このクロージャはエラーを返すことができません。
  - `(a(), b()).map(|(a, b)| MyType { a: a, b: b} )`
  - `recognize(skip_many1(letter())).map(|s| s.to_string())`
- `and_then()`は、3 つの関数の中で最も高機能な関数です。`map()`とは対照的に、クロージャは`Result<>` を返します。例えば、いくつかの数字を数値型にパースする場合など、変換に失敗する可能性がある場合に使用します。
  - `recognize(skip_many1(digit())).and_then(|digits : &str| digits.parse::<u32>().map_err(StreamErrorFor::<I>::other) )` （これは [`from_str(recognize(skip_many1(digit()))`][`from_str`] とも書けます）。
  - エラーを作成するには、`error::StreamError` トレイトの任意のコンストラクタを使用できます。最も役に立つコンストラクタは次のものです。
    - `StreamErrorFor::<I>::other(some_std_error)`
    - `StreamErrorFor::<I>::message_message(format!("{}", xyz))`
    - `StreamErrorFor::<I>::message_static_message("Not supported")`
- `flat_map()`は`and_then()`に非常に似ていますが、クロージャが返さなければならないエラーの種類が異なります。ある出力を別のパーサーでより詳細に解析したい場合には`flat_map()` を使ってください。(そのドキュメントを参照してください)
  - `and_then()` は `error::StreamError` を受け取る一方、`flat_map()` は `error::ParseError` を受け取ります。
  - `and_then()`は自動的にエラーに位置情報を追加しますが、`flat_map()` は自分注意する必要があります。位置情報を追加するような変換が必要かもしれません。

[`parser`]: https://docs.rs/combine/*/combine/trait.Parser.html
[`from_str`]: https://docs.rs/combine/*/combine/fn.from_str.html

### 動的なパース

> You often need to choose a child parser depending on some condition. For example in JSON, you want to parse a list of objects after a `[` and a list of key/object pairs after a `{`. Or you want to parse an escaped string after a `"` and a number when you encounter a digit. This is most easily done with [`choice::choice`][] which takes a tuple of parsers and tries to parse each of them in turn, returning the output of the first successful one.

何らかの条件によって子パーサを選択する必要があることはよくあります。例えば JSON の場合、`[`の後にはオブジェクトのリストを、`{`の後にはキーとオブジェクトのペアのリストをパーズしたいとします。あるいは、エスケープされた文字列を `"` の後に、数字を見つけたときにその数字をパースしたいとします。これは [`choice::choice`][] を使用することで簡単に行うことができます。

```rust
choice::choice( (
    char::char('{').with( parse_key_value_pairs() ),
    char::char('[').with( parse_list() ),
) )
// The error will look like this:
//   Unexpected `<`
//   Expected `{` or `[`
```

> Note that `choice` only attempts the next parser if the previous parser failed to parse the very first token that was fed to it.

`choice` は、前のパーサーが最初に送られたトークンのパースに失敗した場合にのみ、次のパーサーを試すことに注意してください。

```rust
choice::choice( (
    char::string("abc"),
    char::string("a12")
) )
// このパーサーに「a12」を与えても、最初のパーサーが「a」をうまく見つけた後に失敗しただけなので、成功しないでしょう。
```

> To fix this we need to use [`combinator::attempt`][] which makes the wrapped parser act as if it always failed on the first token. (Note that this can be slower and provide worse error messages so avoid using `attempt` unless it is necessary).

これを解決するには、[`combinator::attempt`][]を使用する必要があります。これはラップされたパーサーが、常に最初のトークンで失敗したように動作するようにするものです。これは、ラップしたパーサーを、最初のトークンで失敗したかのように動作させられます (この動作は遅くなり、エラーメッセージも悪くなるので、必要でない限り `attempt` を使わないようにしましょう)。

```rust
choice::choice( (
    combinator::attempt(char::string("abc")),
    combinator::attempt(char::string("a12"))
) )
// OK: Parsed "a12"
```

> [`Parser::or`][] works the same as `choice` and can be useful when there are only two alternatives.

[`Parser::or`][] は、選択肢が２つのみの場合、choice を使いやすく使えるものです。

[`choice::choice`]: https://docs.rs/combine/*/combine/parser/choice/fn.choice.html
[`combinator::attempt`]: https://docs.rs/combine/*/combine/parser/combinator/fn.attempt.html
[`parser::or`]: https://docs.rs/combine/*/combine/trait.Parser.html#method.or

### Repeating elements

> Often, you have repeating elements, for example a list of numbers.

多くの場合、例えば数字のリストなど、繰り返される要素があります。

> First, you need a parser for a single element of that list: `let hexbyte = ( hexdigit(), hexdigit() );`

まず、そのリストの 1 つの要素に対するパーサーが必要です。`let hexbyte = ( hexdigit(), hexdigit() );`。

> Then you can use one of the following combinators to collect multiple occurrences of that element:

次に、以下のコンビネーターのいずれかを使用して、その要素の複数の出現を集めます。

- `repeat::count(4, hexbyte);` - 0 to 4 hexadecimal bytes
- `repeat::count_min_max(1, 4, hexbyte)` - 1 to 4 hexadecimal bytes
- `repeat::many(hexbyte)` - 0 or more hexadecimal bytes
- `repeat::many1(hexbyte)` - 1 or more hexadecimal bytes
- `repeat::sep_by(hexbyte, ',')` - 0 or more hexadecimal bytes, separated by `,`
- `repeat::sep_by1(hexbyte, ',')` - 1 or more hexadecimal bytes, separated by `,`
- `repeat::sep_end_by(hexbyte, ',')` - 0 or more hexadecimal bytes, all followed by `,`
- `repeat::sep_end_by1(hexbyte, ',')` - 1 or more hexadecimal bytes, all followed by `,`

> The parser output of each element will be collected into a type that implements `std::iter::Extend<TheNestedParser::Output>` and `std::default::Default`. You can use `Vec`, `HashMap` or `HashSet` for this purpose or even write your own collection. You must always give a type hint, so the combinator knows which collection to use. The best way to do this is to call `.map(|m : Vec<_>| m)` on the collecting combinator.

各要素のパーサ出力は `std::iter::Extend<TheNestedParser::Output>` と `std::default::Default` を実装した型に収集されます。繰り返しを扱うために、`Vec`、`HashMap`、`HashSet` を使用でき、または独自のコレクション型を記述することもできます。常に型ヒントを与えて、コンビネータがどのコレクションを使用するかを知る必要がある。そのためには収集するコンビネータに対して `.map(|m : Vec<_>| m)` を呼び出すのがもっともよい方法です。

> The following example counts the tools in the inventory list.

次の例はインベントリリストにある tool を数える例です。

```rust
# use std::collections::HashMap;
# use combine::parser::range::{range, take_while1};
# use combine::parser::repeat::{sep_by};
# use combine::parser::Parser;
#
#[derive(Default, Debug)]
struct Tools<'a> (HashMap<&'a str, u32>);

impl<'a> std::iter::Extend<&'a str> for Tools<'a> {
    fn extend<T : IntoIterator<Item = &'a str>> (&mut self, iter : T) {
        for tool in iter.into_iter() {
            let counter = self.0.entry(tool).or_insert(0);
            *counter += 1;
        }
    }
}

let input = "Hammer, Saw, Drill, Hammer";

let tool = take_while1(|c : char| c.is_alphabetic());
let mut tools = sep_by(tool, range(", ")).map(|m: Tools| m);

let output = tools.easy_parse(input).unwrap().0;
// Tools({"Saw": 1, "Hammer": 2, "Drill": 1})

```

### 出力の型を見つける

> The output type of all combinators is stated in the documentation, albeit a little hidden.

すべての combinators の出力型は、少し隠れていますがドキュメントに記載されています。

> First, go to the documentation of the combinator [`repeat::many`][]. Click on the return type, here [`combine::parser::repeat::Many`](https://docs.rs/combine/*/combine/parser/repeat/struct.Many.html). Expand the `impl<..> Parser for X` section. Then you find the exact type next to `type Output`.

まず、コンビネーター [`repeat::many`][] のドキュメントにアクセスします。戻り値の型をクリックして、ここでは [`combine::parser::repeat::Many`] (https://docs.rs/combine/*/combine/parser/repeat/struct.Many.html) を選びます impl<...> Parser for X` セクションを展開します。すると、`type Output`の隣にお目当ての型が見つかります。

> In case of `many`, this type is `F`, meaning that you can choose any type (via a type hint via `.map()`) as long as it implements `Extend<P::Output> + Default`.

`many` の場合、この型は `F` です。つまり、 `Extend<P::Output> + Default` を実装していれば、どんな型でも (`.map()` による型ヒントを介して) 選択することができるのです。

> Another example: `range::recognize` has the output `type Output = <P::Input as StreamOnce>::Range`. Your `Range` type is probably `&str` or `&[u8]`, but you can look up your exact range type in the two tables in the [input machinery](Input-Machinery) documentation.

他の例: `range::recognize` は `type Output = <P::Input as StreamOnce>::Range` という出力を持っています。`Range`の型はおそらく`&str`か`&[u8]` ですが、正確な型は [input machinery](Input-Machinery) のドキュメントにある 2 つの表で調べることができます。

### Miscellaneous

- [`parser1.and(parser2)`][] is a shortcut for `(parser1, parser2)`
- [`choice::optional`][] can be helpful.
- [`repeat::escaped`][] helps parsing escaped strings.

- [`parser1.and(parser2)`][] は `(parser1, parser2)`のショートカットです。
- [`choice::optional`][] は便利です。
- [`repeat::escaped`][] はエスケープ文字のパースに役立ちます。

[`parser1.and(parser2)`]: :https://docs.rs/combine/*/combine/trait.Parser.html#method.and
[`choice::optional`]: https://docs.rs/combine/*/combine/parser/choice/fn.optional.html
[`repeat::escaped`]: https://docs.rs/combine/*/combine/parser/repeat/fn.escaped.html

## Going forward

> I recommend to take some to browse through the parsers and combinators from the `parser` module. This tutorial only mentioned the most important ones, but the more you know the parser toolbox, the better your parsers become.

次にすべきこととして、私は`parser` モジュールのパーサーとコンビネーターに目を通しておくことをお勧めします。このチュートリアルでは最も重要なものだけを取り上げましたが、パーサの道具を知れば知るほど、あなたのパーサはより良くなります。

> Also, take a look at the `examples` folder to see the concepts in action.

また、実装の中でこのコンセプトがどう動くかは examples フォルダをご覧ください。

## その他の入力の型

### `&[u8]` のパース

> Use the parsers from `parser::byte` instead of the parsers from `parser::char`.

`parser::char` の代わりに `parser::byte` を使いましょう。

> `parser::byte::num` helps parsing binary numbers with the correct endianess.

`parser::byte::num` は、正しいエンディアンで 2 進数をパースすることを支援します。

### `&[T]` のパース

> Use the parsers from `parser::item` instead of the parsers from `parser::char`.

`parser::char` の代わりに `parser::byte` を使いましょう。

### イテレータ、もしくは `parser::item` をパースする

> See the chapter "Input Machinery" for more information on the setup.

設定の詳細は「機械的な入力」の章をご覧ください。

> The main difference in relation to the slice based input types is that the input is not `RangeStream`, but only a `Stream`. You need to adapt the `where` clause in all your parsers function definitions.

slice ベースの入力タイプとの主な違いは、入力が `RangeStream` ではなく、単なる `Stream` であることです。すべてのパーサーの関数定義で `where` 節を適用する　　必要があります。

```rust
# use combine::parser::*;
# use combine::parser::Parser;
# use combine::stream::{Stream};
# use combine::error::ParseError;
#
fn tools<'a, I>() -> impl Parser<Input = I, Output = Vec<Vec<u8>>>
where I: Stream<Item = u8>,
      I::Error: ParseError<I::Item, I::Range, I::Position>,
{
    let tool = repeat::many(byte::letter()).map(|m : Vec<u8>| m);
    repeat::sep_by(tool, (byte::byte(b','), byte::byte(b' ')))
}
```

> Without a `RangeStream`, the `range` module is not usable. You can't return slice references to your input either. (This makes `many(letter())` idiomatic again.)

`RangeStream` がなければ、`range`モジュールを使用することはできません。また、入力に対するスライス参照を返すこともできません。(このため `many(letter())` がイディオムになります)。
