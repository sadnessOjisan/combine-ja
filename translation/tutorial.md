
## Code Structure

`combine` is very flexible in regards to its data source and error handling
but for the sake of keeping this tutorial simple I will assume that your
input is `&str` and that you want extended error information. If you need
another input source or want to customize the errors used, see the chapter
"Inner Machinery" for all the options.

Let's start by structuring your parsing code correctly from the beginning.
The 'Hello combine' example works, but only because it only uses the each
parser once. To make it re-usable and testable we package it into a
function. We also add the `decode()` function to make handle some
organizational stuff like transforming the error type.

The code otherwise does the same parsing as 'Hello combine' example in
listing A-1 from the first chapter. Errors are returned as String here, in
your own code you would likely have your own error type instead. The only
real difference is, that I wrapped the input with a
[`State`](https://docs.rs/combine/*/combine/stream/state/struct.State.html)
which adds line and column information to the parser errors.

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
*Listing T-1 - 'Hello combine' example, extended*

Any parser that we want to use more than once must be defined in the form `fn xyz() -> impl Parser`, like `tools` in the above example. To use such a parser, you must call the function instead of using it like a variable: `tools()` in listing T-1 vs `tools` in listing A-1.

Whenever you create new `fn` parsers, just copy the whole `fn` header from
this example, including the `where` clause. Change the function name and
adapt the `Output` type. The `I::Error` line is noisy, but unfortunately
necessary due to [rust-lang/rust#24159][]. If that is too noisy for you, see
chapter TODO.

[rust-lang/rust#24159]:https://github.com/rust-lang/rust/issues/24159

## Parsing

Parsing starts at the beginning of the input. The parser then goes forward
character by character, deciding what to do next on every step. It can go
back a few steps and try something else if it hit a dead end in its
logic. It can decide its decoding path on data it has seen previously.

Each parser returns some output value which is assembled from the processed
characters and/or the output of nested parsers. A parser can alternatively
return an error condition if the input did not match its expectations.

For all primitive parsers like `digit()` applies: If a parser read and
processed some bytes from the input stream, the bytes are consumed and
subsequent parsers start where the previous one finished (however there are
some special combinators which break this rule).

## Understanding the Output type

To write parsers effectively, you must understand what happens with the
output values.

At the end, there is only a single output type/value. This type/value must
contain all the information you want to extract.

During the parsing process, new outputs arise, some outputs are `map()`ped
to different types, some are merged and some are dropped. Fortunately, there
is an expressive toolset to manage this.

Let's first look at a parser that has no nested parsers:
`parser::char::digit`. This parser has the output type `char` and consumes
one character of the input stream. The output value will be the consumed
character. It errors if the consumed character is no digit (0-9).

The most basic combination of parsers is sequencing and the simplest way
this can be done by putting them in a tuples. The output of that tuple
parser is also a tuple.

```rust
let two_digits = (digit(), digit()); // Output = (char, char)
```

Only chaining parsers using tuples would make the output type very complicated very soon as the output would be an equally large tuple. Fortunately, we have several options to remedy this:
 - Drop (unneeded) parts of the output type by mapping or processing it:
    `let first_digit = (digit(), digit()).map(|(digit1, _digit2)| digit1);`
    Note: There are often more expressive helpers like [`skip`][] or [`with`][]:
    `let first_digit = digit().skip(digit());`
 - Collect repeating elements into a `Vec` or similar.
 - Ignoring a complicated output type and instead taking a `&str` slice of what has been consumed: `let two_digits_str = recognize( (digit(), digit()) );`
 - Assemble your (complex/recursive) output type, for example `json::Value`.

But there is no fits-all strategy, it all depends on your parsing problem.

[`parser::char::digit`]:https://docs.rs/combine/*/combine/parser/char/fn.digit.html
[`with`]:https://docs.rs/combine/*/combine/trait.Parser.html#method.with
[`skip`]:https://docs.rs/combine/*/combine/trait.Parser.html#method.skip

## Understanding your parsing problem

Research your parsing problem. Make sure you really understand what you want to parse. If, for example you want to parse a JPEG header:
 - Is there an official specification?
 - Does the real world follow the specification? (often not 100%)
 - Search for other resources like blog posts, they may contain helpful clues. 
 - Gather examples from different sources, and include them in you tests to catch problems early on.

## Sketch your desired output

Sketch the type structure that the parser should ideally return. Decide if
the parser output needs to be owned (`String`, ...) or if you want to
exercise zero-copy so the output references parts of the input (`&str`,
...).

## Learn by example

That was a lot of information, but you have not yet any clue on how to write
parsers yet? Let's go step by step by showing little examples and explain
what common problem they solve.

All parsers and combinators live in the `parser` module, even if some of
them are reexported to the main module. In the following chapters, we assume
`use combine::parser::*;`

(Most examples use the [`char`][] module, if you are parsing bytes and not
strings there is often an equivalent function in the [`byte`][] module.)

[`char`]:https://docs.rs/combine/*/combine/parser/char/index.html
[`byte`]:https://docs.rs/combine/*/combine/parser/byte/index.html

### Parse constant characters/slices

Often, a format contains some constant parts. You need to check for their
existence, but they don't matter for the parsers output.

Use [`char::char('x')`][char::char] for characters and
[`char::string("abcde")`][char::string] (or
[`range::range("abcde")`][range::range] if zero-copy) for slices. The output
type of these parsers is `char` and `&str` respectively.

[char::char]:https://docs.rs/combine/*/combine/parser/char/fn.char.html
[char::string]:https://docs.rs/combine/*/combine/parser/char/fn.string.html
[range::range]:https://docs.rs/combine/*/combine/parser/range/fn.range.html

### Parse character classes, for example whitespace

Human readable formats like JSON ignore whitespace (spaces, tabs,
newlines). [`char::space`][] parses all whitespace characters according to
the unicode White_Space category. Look into the `parser::char` module for
more predefined character classes.

Use [`token::satisfy`][] to define your own character classes. For example
`token::satisfy(|c| c != '\n')` parses everything except a newline. (You may
not that this is in the [`token`][] module which means it works regardless
of the input type).

The output of each of these parsers is the `char` they have matched.

[`char::space`]:https://docs.rs/combine/*/combine/parser/char/fn.space.html
[`token::satisfy`]:https://docs.rs/combine/*/combine/parser/token/fn.satisfy.html
[`token`]:https://docs.rs/combine/*/combine/parser/token/index.html

### Parse consecutive whitespace or words

All the above parsers match just a single letter. Sometimes we want to parse
words or consecutive whitespace. This can be done by using the parser
combinators from [`repeat`][].

If you want to ignore the matched characters, you can use `repeat::skip_*` functions:
 - `skip_many(space())` - 0 or more whitespace characters (same as `char::spaces()`)
 - `skip_many1(space())` - 1 or more whitespace characters
 - `skip_count(4, space())` - exactly 4 whitespace characters
 - `skip_count_min_max(1, 4, space())` - 1 to 4 whitespace characters
 - `skip_until(token::satisfy(|c| c != '\n'))` - everything until the end of line

The `skip_*` combinators have the output type `()`, but they nonetheless
consume from the input stream.

On the other hand, if you want to have the consumed slice as output, things
are more complicated. [`repeat::many`][] works and can easily be used to
collect into a `String`, `Vec` or any other type that implements
`Extend`. However, for collecting single characters it may not be performant
enough.

Thus there are some additional alternatives, depending on how you can
describe the characters to consume.

 - `range::recognize(repeat::skip_many1(char::letter()))` - Use this if you
   want to describe the range of interest as a combination of other
   parsers. Because the output of the inner parsers doesn't matter, you can
   use the `skip_*` combinators. [`range::recognize`][] will then look at
   what has been consumed by its inner parser(s) and use that range/slice as
   its output.
 - `range::take_while1(|c| c.is_alphabetic())` - Here you can inspect
   characters using a closure. Similar to `skip_until(item::satisfy(..))`
   (but inverse logic).
 - `range::take_until_range(">>>")` - Wait for a constant and return
   everything that has been consumed before that constant occurred.

(These parsers and more like them all exist in the [`range`][] module which
contains parsers specialized to zero-copy input such as `[u8]` and `str`, if
you have a different input you may need to make do with [`repeat::many`][]

[`repeat`]:https://docs.rs/combine/*/combine/parser/repeat/index.html
[`repeat::many`]:https://docs.rs/combine/*/combine/parser/repeat/fn.many.html
[`range::recognize`]:https://docs.rs/combine/*/combine/parser/range/fn.recognize.html
[`range`]:https://docs.rs/combine/*/combine/parser/range/index.html

### Transforming the output

At any time, you can manipulate the output value. You can for example drop
some parts of it or parse a `&str` made of digits to an `u32`.

The relevant functions are part of the [`Parser`][] trait, so you use the
`.` notation: `digit().map(|d| d)`.

```rust
    fn map<>(self, f: impl FnMut(O) -> B) -> impl Parser<Output = B> {}
    fn and_then<>(self, f: impl FnMut(O) -> Result<B, S_ERR>) -> impl Parser<Output = B> {}
    fn flat_map<>(self, f: impl FnMut(O) -> Result<B, P_ERR>) -> impl Parser<Output = B> {}
```

The return value of these three functions is a parser again. This is similar
to calling `map()` on an `std::iter::Iterator`, which returns an `impl
Iterator` again. Like `Iterator`, after combining all the parsers, you have
not parsed anything yet, just created an instance of a type that is able to
parse your input. Just like iterating starts when calling `next()`, parsing
starts when calling `parse*()`.

What is the difference between these functions and when to use them?
 - `map()` allows you to map the output to another type. For example you can convert a `&str` to a `String`, or move some values from tuple form into a custom struct. The closure is not able to return an error.
     + `(a(), b()).map(|(a, b)| MyType { a: a, b: b} )`
     + `recognize(skip_many1(letter())).map(|s| s.to_string())`
 - `and_then()` is the most capable of the three functions. In contrast to `map()`, the closure returns a `Result<>`. Use this if your transformation may fail, for example if you want to parse some digits into a numeric type. 
     + `recognize(skip_many1(digit())).and_then(|digits : &str| digits.parse::<u32>().map_err(StreamErrorFor::<I>::other) )` (This could also be written with [`from_str(recognize(skip_many1(digit())))`][`from_str`])
     + You can use any constructor of the `error::StreamError` trait to create an error. The most helpful constructors are:
         * `StreamErrorFor::<I>::other(some_std_error)`
         * `StreamErrorFor::<I>::message_message(format!("{}", xyz))`
         * `StreamErrorFor::<I>::message_static_message("Not supported")`
 - `flat_map()` is very similar to `and_then()`, but they differ in the error type the closure must return. Use `flat_map()` if you want to parse some output in more detail with another parser. (see its documentation)
     + `and_then()` takes an `error::StreamError` where as `flat_map()` takes an `error::ParseError`.
     + `and_then()` will add position information to the error automatically, for `flat_map()` you have to take care of that yourself. You may need to transform the position information.

[`Parser`]:https://docs.rs/combine/*/combine/trait.Parser.html
[`from_str`]:https://docs.rs/combine/*/combine/fn.from_str.html

### Dynamic parsing

You often need to choose a child parser depending on some condition. For
example in JSON, you want to parse a list of objects after a `[` and a list
of key/object pairs after a `{`. Or you want to parse an escaped string
after a `"` and a number when you encounter a digit. This is most easily
done with [`choice::choice`][] which takes a tuple of parsers and tries to
parse each of them in turn, returning the output of the first successful
one.

```rust
choice::choice( (
    char::char('{').with( parse_key_value_pairs() ),
    char::char('[').with( parse_list() ),
) )
// The error will look like this:
//   Unexpected `<`
//   Expected `{` or `[`
```

Note that `choice` only attempts the next parser if the previous parser
failed to parse the very first token that was fed to it.

```rust
choice::choice( (
    char::string("abc"),
    char::string("a12")
) )
// If we feed this parser with "a12" it will not succeed as the first parser only failed after already having found a 'a' successfully
```

To fix this we need to use [`combinator::attempt`][] which makes the wrapped
parser act as if it always failed on the first token. (Note that this can be
slower and provide worse error messages so avoid using `attempt` unless it
is necessary).

```rust
choice::choice( (
    combinator::attempt(char::string("abc")),
    combinator::attempt(char::string("a12"))
) )
// OK: Parsed "a12"
```

[`Parser::or`][] works the same as `choice` and can be useful when there are
only two alternatives.

[`choice::choice`]:https://docs.rs/combine/*/combine/parser/choice/fn.choice.html
[`combinator::attempt`]:https://docs.rs/combine/*/combine/parser/combinator/fn.attempt.html
[`Parser::or`]:https://docs.rs/combine/*/combine/trait.Parser.html#method.or

### Repeating elements

Often, you have repeating elements, for example a list of numbers.

First, you need a parser for a single element of that list: `let hexbyte = (
hexdigit(), hexdigit() );`

Then you can use one of the following combinators to collect multiple occurrences of that element:
 - `repeat::count(4, hexbyte);` - 0 to 4 hexadecimal bytes
 - `repeat::count_min_max(1, 4, hexbyte)` - 1 to 4 hexadecimal bytes
 - `repeat::many(hexbyte)` - 0 or more hexadecimal bytes
 - `repeat::many1(hexbyte)` - 1 or more hexadecimal bytes
 - `repeat::sep_by(hexbyte, ',')`  - 0 or more hexadecimal bytes, separated by `,`
 - `repeat::sep_by1(hexbyte, ',')`  - 1 or more hexadecimal bytes, separated by `,`
 - `repeat::sep_end_by(hexbyte, ',')`  - 0 or more hexadecimal bytes, all followed by `,`
 - `repeat::sep_end_by1(hexbyte, ',')`  - 1 or more hexadecimal bytes, all followed by `,`

The parser output of each element will be collected into a type that implements `std::iter::Extend<TheNestedParser::Output>` and `std::default::Default`. You can use `Vec`, `HashMap` or `HashSet` for this purpose or even write your own collection. You must always give a type hint, so the combinator knows which collection to use. The best way to do this is to call `.map(|m : Vec<_>| m)` on the collecting combinator.

The following example counts the tools in the inventory list.

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

### Finding the output type

The output type of all combinators is stated in the documentation, albeit a
little hidden.

First, go to the documentation of the combinator [`repeat::many`][]. Click on the return type, here [`combine::parser::repeat::Many`](https://docs.rs/combine/*/combine/parser/repeat/struct.Many.html). Expand the `impl<..> Parser for X` section. Then you find the exact type next to `type Output`.

In case of `many`, this type is `F`, meaning that you can choose any type (via a type hint via `.map()`) as long as it implements `Extend<P::Output> + Default`.

Another example: `range::recognize` has the output `type Output = <P::Input as StreamOnce>::Range`. Your `Range` type is probably `&str` or `&[u8]`, but you can look up your exact range type in the two tables in the [input machinery](Input-Machinery) documentation.

### Miscellaneous

 - [`parser1.and(parser2)`][] is a shortcut for `(parser1, parser2)`
 - [`choice::optional`][] can be helpful.
 - [`repeat::escaped`][] helps parsing escaped strings.

[`parser1.and(parser2)`]::https://docs.rs/combine/*/combine/trait.Parser.html#method.and
[`choice::optional`]:https://docs.rs/combine/*/combine/parser/choice/fn.optional.html
[`repeat::escaped`]:https://docs.rs/combine/*/combine/parser/repeat/fn.escaped.html

## Going forward

I recommend to take some to browse through the parsers and combinators from
the `parser` module. This tutorial only mentioned the most important ones,
but the more you know the parser toolbox, the better your parsers become.

Also, take a look at the `examples` folder to see the concepts in action.


## Other input types

### Parsing `&[u8]`

Use the parsers from `parser::byte` instead of the parsers from
`parser::char`.

`parser::byte::num` helps parsing binary numbers with the correct endianess.

### Parsing `&[T]`

Use the parsers from `parser::item` instead of the parsers from
`parser::char`.

### Parsing from Iterators or `std::io::Read`

See the chapter "Input Machinery" for more information on the setup.

The main difference in relation to the slice based input types is that the
input is not `RangeStream`, but only a `Stream`. You need to adapt the
`where` clause in all your parsers function definitions.

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

Without a `RangeStream`, the `range` module is not usable. You can't return
slice references to your input either. (This makes `many(letter())`
idiomatic again.)
