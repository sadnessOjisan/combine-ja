## Overview

`combine`'s default error handling is very simple. Let's look at a simple
example that does not use the `easy` module.

```rust
# use combine::parser::char::char;
# use combine::parser::Parser;
# use combine::error::StringStreamError;

assert_eq!(Err(StringStreamError::UnexpectedParse), 
           char('s').parse("e"));
```

The parser expects an 's' literal, but the input is "e", so the parser
returns an error. The exact error is `StringStreamError::UnexpectedParse`
which only tells us that we got a parser error somewhere for an unspecified
reason. If we are parsing for example a config file with a syntax error,
this information wouldn't help us at all fixing the config file.

`combine` uses this simple error strategy to support `no_std` environments, but since this is unlikely to be enough for many use-cases its error handling is extensible.
 The easiest way opt in into more precise error messages by using the aptly named `easy` machinery.

```rust
# use combine::parser::char::char;
# use combine::parser::Parser;
# use combine::stream::state::State;
let result = char('s').easy_parse(State::new("e"));

let formatted_err = &format!("{}", result.unwrap_err());

assert_eq!(
"Parse error at line: 1, column: 1
Unexpected `e`
Expected `s`
", formatted_err);
```

By using `easy_parse` instead of `parse` we tell `combine` to use the
[`easy::Errors`][] as the error type which gives us much more detailed
information about where the parsing went wrong.

The input data is also wrapped in [`State`][] which further enhances the
error by making the position information line and column based. Otherwise
the position would simply point to some memory address ("Parse error at
0x55e618410520"), which would not be reproducible within tests.

For `&[T]` input, or if line and column indication don't make sense for your
application, you can use [`translate_position`][] instead of the `State`
wrapper to map the memory address based position to an offset. By the way:
`.parse(easy::Stream(input))` is equivalent to .easy_parse(input).

[`State`]:https://docs.rs/combine/*/combine/stream/state/struct.State.html
[`easy::Errors`]:https://docs.rs/combine/*/combine/easy/struct.Errors.html
[`translate_position`]:https://docs.rs/combine/*/combine/stream/struct.PointerOffset.html#method.translate_position

```rust
# use combine::parser::char::char;
# use combine::parser::Parser;
# use combine::stream::easy;
let input = "e";
let result = char('s').parse(easy::Stream(input)); // same as .easy_parse(input);
let result = result.map_err(|e| e.map_position(|p| p.translate_position(input)));

let formatted_err = &format!("{}", result.unwrap_err());

assert_eq!(
"Parse error at 0
Unexpected `e`
Expected `s`
", formatted_err );
```

[`translate_position`][] requires a reference to original input slice. If
you don't have that because your data source is `Iterator` based, you can
get the same effect by wrapping the input with
`State::with_positioner(input, IndexPositioner)`.

## The error traits

Its time to look behind the curtain.

As often in the rust world, flexibility is created by using generics, traits
and different implementations for different types.

For errors in `combine`, there are two traits: `error::ParseError` and
`error::StreamError`.

`combine` implements these traits for the following types, but you could add
your own types and implementations as well:

```rust
impl StreamError for StringStreamError {} 
impl ParseError  for StringStreamError { type StreamError = Self }

impl StreamError for UnexpectedParse   {}
impl ParseError  for UnexpectedParse   { type StreamError = Self }

impl StreamError for easy::Error       {}
impl ParseError  for easy::Error       { type StreamError = Self }

impl ParseError  for easy::Errors      { type StreamError = easy::Error }

```

How does the parser know which error type to use? The parser trait has an
associated type `Input : Stream`, which itself has the associated type
`Error : ParseError`. Whatever that type is, is used as the actual error
type.

You may ask why the error is defined on the input stream. The answer is,
that the stream methods `uncons()`, `uncons_range()` and `uncons_while()`
need to be able to return errors, too, and it saves a lot of type
boilerplate when the stream and the parser do not need to be generic over
any error.

Note: Since most parsers are generic in terms of their input type (as long
as it is a `Stream`), you can combine any parser with any error stategy and
any input. To select an error strategy, you need to create a wrapper around
the actual `input` that reassigns the associated `Error` type. That wrapper
needs to do some `map_err()` calls in its implementation and that's it. That
is what the input wrapper `easy::Stream` is doing.

Because the parser can access the error type, and the error traits define a
few constructor methods, the parser can create and return new errors when
needed. Some constructors take meta data. It is up to the error type
implementation to store or ignore this meta data.

These are the two error traits:

```rust
trait StreamError<Item, Range>: Sized + PartialEq {

    // CONSTRUCTORS

    fn unexpected               (info:  Info<Item, Range>) -> Self { ... }
    fn unexpected_token         (token: Item)              -> Self;
    fn unexpected_range         (token: Range)             -> Self;
    fn unexpected_message       (msg:   impl Display)      -> Self;
    fn unexpected_static_message(msg:   &'static str)      -> Self { ... }
    fn expected                 (info:  Info<Item, Range>) -> Self { ... }
    fn expected_token           (token: Item)              -> Self;
    fn expected_range           (token: Range)             -> Self;
    fn expected_message         (msg:   impl Display)      -> Self;
    fn expected_static_message  (msg:   &'static str)      -> Self { ... }
    fn message                  (info:  Info<Item, Range>) -> Self { ... }
    fn message_token            (token: Item)              -> Self;
    fn message_range            (token: Range)             -> Self;
    fn message_message          (msg:   impl Display)      -> Self;
    fn message_static_message   (msg:   &'static str)      -> Self { ... }
    fn end_of_input             ()                         -> Self { ... }
    fn other<E>                 (err:   impl StdError + .) -> Self { ... }

    // COPY into other StreamError

    fn into_other<T>(self) -> T where T: StreamError<Item, Range>;
}


trait ParseError<Item, Range, Position>: Sized + PartialEq {

    type StreamError: StreamError<Item, Range>;

    // CONSTRUCTOR

    fn empty(position: Position) -> Self;
    fn from_error(position: Position, err: Self::StreamError) -> Self;

    // COPY into other StreamError

    fn into_other<T>(self) -> T where T: ParseError<Item, Range, Position>;

    // MODIFICATION

    fn set_position(&mut self, position: Position);
    fn add(&mut self, err: Self::StreamError);
    fn set_expected<F>(self_: &mut Tracked<Self>, info: Self::StreamError, f: F) where F: FnOnce(&mut Tracked<Self>);
    fn merge(self, other: Self) -> Self { ... }
    fn add_expected(&mut self, info: Info<Item, Range>) { ... }
    fn add_unexpected(&mut self, info: Info<Item, Range>) { ... }
    fn add_message(&mut self, info: Info<Item, Range>) { ... }
    fn clear_expected(&mut self) { ... }

    // QUERY

    fn is_unexpected_end_of_input(&self) -> bool;
}
```

So let's first look at all the constructors of the two error traits.

`StreamError` is able to take information about the type of error
(expected/unexpected/&str) where as `ParseError` is `empty()` at first, but
allows `StreamError`s to be `add()`ed to it. Also note that a `ParseError`
has an associated type `StreamError`. They come in pairs.

The documentation of `StreamError` states: "`StreamError` represents a
single error returned from a `Stream` or a `Parser`.  Usually multiple
instances of `StreamError` are composed into a `ParseError` to build the
final error value."

## Minimal errors and maximal performance

Now let's look at the implementations:

```rust
pub enum UnexpectedParse {
    Eoi,
    Unexpected,
}
```

`UnexpectedParse` is the minimal error type for all input types except
`&str`.

When a new `UnexpectedParse` is contructed, for example with
`Error::unexpected_range(some_range)`, the range information is not used,
and the new error is just a `UnexpectedParse::Unexpected`. The same applies
to all other constructors except for `end_of_input()`, which becomes
`UnexpectedParse::Eoi`. The "end of input" error needs special handling
because it is part of the partial parsing machinery. The parser may ask the
error type with `e.is_unexpected_end_of_input()`, if the reason was Eoi. The
Eoi information must be OR-ed when adding adding/merging multiple
`StreamError`s into a `ParseError`.

```rust
pub enum StringStreamError {
    UnexpectedParse,
    Eoi,
    CharacterBoundary,
}
```

`StringStreamError` is the minimal error type for `&str` input. It has the
additional variant `CharacterBoundary`. When handling utf-8 encoded data and
taking slices by byte offset, it is possible to create illegal strings. See
[split_at](https://doc.rust-lang.org/std/primitive.str.html#method.split_at
). I will not explain this further because it is mostly an implementation
detail like `Eoi`.

## Informative errors with `easy`

That was the default error parsing. Now we take a look what errors are used
when we wrap our input in `easy::Stream`.

Mainly, the inputs associated type `Errors` becomes `easy::Errors`. Because
of convenience, you will see the `easy::ParseError` type instead, but they
are the same.

All the constructors from the `StreamError` trait map into the respective
variants of `easy::Error`. Multiple errors are collected into the `Vec`
inside of `easy::Errors.` The data structures are all `pub`, so you can
access all the fields for inspection. The error also implements `Display`,
`Debug` and `std::error::Error`.

```rust
type easy::ParseError<S> = easy::Errors<...... >;

// I = input::Item, R = input::Range, P = input::Position
pub struct easy::Errors<I, R, P> {  // `ParseError`
    pub position: P,
    pub errors: Vec<Error<I, R>>,
}

pub enum easy::Error<T, R> {        // `StreamError`
    Unexpected(Info<T, R>),
    Expected(Info<T, R>),
    Message(Info<T, R>),
    Other(Box<dyn StdError + Send + Sync>),
}

pub enum easy::Info<T, R> {  
    Token(T),
    Range(R),
    Owned(String), // Note: There exists another `Info` without the `Owned` variant
    Borrowed(&'static str),
}
```

Usage examples were given at the beginning of the error chapter. You may now
understand them better. If you want to implement your own Error type, take a
look at the source code of the `easy` module.
