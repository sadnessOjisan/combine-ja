This is all about the data to parse and how to feed it into the parser.

For many use cases the full input data is available as `&str` or
`&[u8]`. This is like the best food for any parser implementation because
the parser can happily jump back to previous positions in the input data and
can efficiently match constant subslices with `memcmp` because the input
data is laid out in contiguous memory.

In addition to parsing slices `combine` also wants to support more
constrained environments:

* The input could be stored in a fixed size ring buffer. Then the parser
  cannot use `memcmp` anymore because a ring buffers memory is not
  contiguous.
* The input could come from a `Read` instance which only delivers its input
  byte by byte without any type of buffering (say a serial peripheral in a
  microcontroller).
* The input could be in the form of an `Iterator` of tokens from an earlier
  lexical pass.

`combine` is also liberal in the type of the input data. It does not have to
be a `char` or `u8`. Any type is allowed, as long as it is `Clone` and
`PartialEq`.

To classify the abilities of the data source and to allow for more efficient
parsing when the data source supports it, `combine` uses a trait
hierarchy. You find all these traits under `combine::stream`.

```
   ----------------------------- more capable ------------>

   StreamOnce    Positioned    ResetStream    RangeStreamOnce
         ^          |              ^             |  |         
         |----------┘              └-------------┘  |         
         └------------------------------------------┘            <--- these arrows mean "requires"
                                                           
   \___________________________________/                   
                   Stream                                  
   \_________________________________________________________/
                        RangeStream
```

Every data source need to implement the base trait `StreamOnce`. Depending
on the capabilities of the data source, it may also implement the traits
listed right of `StreamOnce`. The traits are ordered; traits to the right
require more and more. `Stream` and `RangeStream` are abbreviations and are
automatically implemented for data sources that implement all the traits
enclosed by the braces `\__/`.

## The basic stream

`StreamOnce` provides a method to gather one input element at a time. An
input element is `char`, `u8` or any self defined type that implements
`Clone` and `PartialEq` as is defined by the `Token` associated type. The
data source does not need to provide slices of multiple elements, nor
jumping back to previous positions in the stream. `StreamOnce` is also the
trait that contains the most important associated types for a data
source. (The `Range` and `Position` associated types are only meaningful if
the data source implements `Positioned` / `RangeStreamOnce`. But because
these types depend on the input `Token` type, they are all defined
together. If a data source does not implement `RangeStreamOnce`, it simply
sets it's `Range` type to `&'static [Self::Token]` or `Token` type.)

For reference, here is the `StreamOnce` definition:

```rust
pub trait StreamOnce {
    type Token: Clone + PartialEq;
    type Range: Clone + PartialEq;
    type Position: Clone + Ord;
    type Error: ParseError<Self::Token, Self::Range, Self::Position>;
    fn uncons(&mut self) -> Result<Self::Token, StreamErrorFor<Self>>;
    fn is_partial(&self) -> bool { ... }
}
```

Next up the hierarchy is `Positioned`. The stream position is mostly opaque
to the parser. It is not used to return to some previous position in the
input data or to calculate lengths/distances. The parser only ever uses it
check which of two positions is further ahead in a stream
(`StreamOnce::Position : Ord`). Because `Position` has so few constraints,
`combine` uses it to track line and column numbers for `&str` input on the
fly. Of course this extra work is Opt-In.

```rust
pub trait Positioned: StreamOnce {
    fn position(&self) -> Self::Position;
}
```

Next up is `Resetable`. With a `Resetable` data source, the parser can
return to a previously seen position within the stream / look into the
future. In context of `Resetable` such a position is called a
checkpoint. This is used for combinators like `attempt()` or `choice()`.

Note that the parser doesn't clone the stream, it can only reset the stream
to some position it has previously seen. This trait requires that the data
source does some kind of buffering but does not require the data source to
use contiguous memory.

(`Resetable` may change in the next version of combine to handle errors if
the past is already deleted: https://github.com/Marwes/combine/issues/231).

```rust
pub trait Resetable {
    type Checkpoint: Clone;
    fn checkpoint(&self) -> Self::Checkpoint;
    fn reset(&mut self, checkpoint: Self::Checkpoint);
}
```

These first three trait combined becomes a `Stream` which is the constraint
that most of `combine`'s parsers need. Often though we want to use zero-copy
parsing which is where the remaining traits come in.

## Zero-copy streams

With a `RangeStreamOnce` data source, the parser becomes able to do zero
copy parsing. The `StreamOnce::Range` type typically is a reference type as
well as `Clone + PartialEq` and therefore allows for zero copy
comparisions. It is possible to implement a `Range` type for non contiguous
memory, but typically this type takes advantage of the continuity of the
underlying memory.

`RangeStreamOnce` extends the `Resetable` mechanism by allowing to calculate
a distance between checkpoints. The two `usize`s below refer to number of
elements. In the case of `&str`, this refers to the number of bytes, not the
number of unicode codepoints.

```rust
pub trait RangeStreamOnce: StreamOnce + Resetable {
    fn uncons_range(&mut self, size: usize) -> Result<Self::Range, StreamErrorFor<Self>>;
    fn uncons_while<F>(&mut self, f: F) -> Result<Self::Range, StreamErrorFor<Self>>
        where F: FnMut(Self::Token) -> bool;
    fn distance(&self, end: &Self::Checkpoint) -> usize;
}
```

### Provided implementations

`combine` supports `&str`, `&[T]`, `Iterator` and `Read` as data source out
of the box.

 - `&str` and `&[T]` (if T:Clone) can just be used as input for parsing.
   - If `T` in `&[T]` is not `Clone` or if cloning is expensive, the
     `SliceStream` wrapper comes to the rescue. Wrapping the input slice in
     this type makes the `Token` a `&T`.
 - Any `Iterator` can be turned into a data source by wrapping it in
   `IteratorStream` with `IteratorStream::new(intoiter)`.
 - Any `std::io::Read` byte source can be turned into a data source by
   wrapping it in `ReadStream` with `ReadStream::new(read)`.

The following table lists the implemented traits and the resulting types for
each of the mentioned data sources.

```
pub struct SliceStream<'a, T: 'a>(pub &'a [T]);
pub struct IteratorStream<I>( ... ); // I : Iterator
pub struct ReadStream<R> { ... } // R : Read

|                         | &str               | &[T], T : Clone  | SliceStream<T>    | IteratorStream<I>  | ReadStream<R : Read>   |
|-------------------------|--------------------|------------------|-------------------|--------------------|------------------------|
| trait StreamOnce        | x                  | x                | x                 | x                  | x                      |
|   ↳ type Token          |  char              |  T               |  &T               |   I::Token         |  u8                    |
|   ↳ type Range          |  &str              |  &[T]            |  &[T]             |   I::Token         |  u8                    |
|   ↳ type Position       |  PointerOffset     |  PointerOffset   |  PointerOffset    |   ()               |  usize                 |
|   ↳ type Error          |  StringStreamError |  UnexpectedParse |  UnexpectedParse  |   UnexpectedParse  |  Errors<u8, u8, usize> |
|   ↳ fn is_partial       |  return false      |  return false    |  return false     |   return false     |  return false          |
| trait Positioned        | x                  | x                | x                 |                    |                        |
| trait Resetable         | x                  | x                | x                 | x if I : Clone     |                        |
|   ↳ type Checkpoint     |  &str              |  &[T]            |  &[T]             |                    |                        |
| trait RangeStreamOnce   | x                  | x                | x                 |                    |                        |
| trait DefaultPositioned | x                  | x                | x                 | x                  | x                      |
|   ↳ type Positioner     |  SourcePosition    |  IndexPositioner |  IndexPositioner  |  IndexPositioner   |  IndexPositioner       |
```
`combine` also provides some wrappers which add functionality to less
capable stream types or alter their behaviour.

 - `PartialStream`: Wrapping the data source in this type changes the parser
   behaviour: If the parser hits the end of the input stream and has not
   found any error yet, it will gracefully ask for more data instead of
   erroring.
 - `State`: Wrapping in `State` changes the `Position` type. You can either
   choose your own `Positioner` by wrapping with `State::with_positioner(s,
   x)` or using the default positioner by wrapping with `State::new(s)`. You
   find the used default positioner in the last row in the two tables above
   and below.
   - Because position tracking is stateful, the corresponding state (the
     struct that implements `Positioner`) must be included when creating
     checkpoints. The `State` wrapper is reused as `Checkpoint` type, but
     that is only an implementation detail.
   - Note that there are two kinds of default positioners at play
     here. First, the default positioner of a plain `&str`, ... which is
     `PointerOffset` (or `usize` for `ReadStream` or `()` for
     `IteratorStream`). Second the positioner that is applied when using
     `State::new(s)` which is `SourcePosition` or `IndexPositioner`.
   - `PointerOffset` is most simple but absolutely performant. It does not
     count anything but is just a raw memory address. If an error type
     contains position information in `PointerOffet` format, you need to
     call `translate_position()` on the `PointerOffset`, so that you can
     make sense of the information.
   - `IndexPositioner` will actively count the number of items from the
     start of the stream.
   - `SourcePosition` will track the line and column number on the fly by
     looking out for `\n`. This adds some additional work, but it obviates
     going through the whole input data again just for making a index based
     error message / position data human friendly.
 - `BufferedStream`: As you can see in the table above, `IteratorStream` and
   `ReadStream` don't implement `Positioned` and `Resetable` and therefore
   not `Stream`. But most of the parser combinators require the input type
   to be at least a `Stream`. `BufferedStream` helps with
   that. `BufferedStream` uses a fixed size `VecDeque` to add `Resetable`
   and `Positioned` to a `StreamOnce` data source.
   - What happens if the parser wants to reset to a checkpoint that has
     already been removed from the ring buffer? `BufferedStream` allows to
     `reset()` to any previous checkpoint, even when it points to deleted
     data. When the parser calls `uncons()` after it has been reset to a
     deleted data, `uncons()` returns `Err()` with the static string error
     message: "Backtracked to far".
   - When creating the wrapper, you must define the size of the ring buffer
     / the look ahead ability. The buffer size must fit your parsing
     problem. Note that `BufferedStream` does not read items from the
     underlying stream in advance, but only when needed, so the whole buffer
     size is available for backtracking.
 - `easy::Stream` (Don't confuse that with the trait `Stream`): This Wrapper
   changes the `Error` type to `easy::ParserError`. The default error type
   (except for `ReadStream`) is `StringStreamError` or
   `UnexpectedParse`. These error types are simple enums without any
   associated data. Therefore these errors types do not track the kind of
   error or the position of the error in the input data. This is good for
   no_std environments where allocating is difficult. But when you are
   interested in more exact details about the parser error and you are fine
   with allocating all error messages into a `Vec<>`, then just wrap a data
   source in an `easy::Stream`. See the chapter about the error machinery
   for more details.


```
pub struct PartialStream<S>(pub S);
pub struct State<I, X> {
    pub input: I,
    pub positioner: X,
}
pub struct BufferedStream<I> where I: StreamOnce + Positioned,  { /* fields omitted */ }
pub struct easy::Stream<S>(pub S);

|                         | PartialStream<S>         | State<S, X : Positioner>         | BufferedStream<S>        | easy::Stream<S>          |
|-------------------------|--------------------------|----------------------------------|--------------------------|--------------------------|
| trait StreamOnce        | x if S : StreamOnce      | x                                | x                        | x if S : StreamOnce      |
|   ↳ type Token          |  S::Token                |  S::Token                        |  S::Token                |  S::Token                |
|   ↳ type Range          |  S::Range                |  S::Range                        |  S::Range                |  S::Range                |
|   ↳ type Position       |  S::Position             |  X::Positon                      |  S::Position             |  S::Position             |
|   ↳ type Error          |  S::Error                |  S::Error                        |  S::Error                |  easy::ParseError<S>     |
|   ↳ fn is_partial       |  return *true*           |  return S::is_partial            |  return S::is_partial    |  return S::is_partial    |
| trait Positioned        | x if S : Positioned      | x if S : Positioned              | x                        | x if S : Positioned      |
| trait Resetable         | x if S : Resetable       | x if S : Resetable               | x even if S : !Resetable | x if S : Resetable       |
|   ↳ type Checkpoint     |  S::Checkpoint           |  State<I::Checkp.., X::Checkp..> |  usize                   |  S::Checkpoint           |
| trait RangeStreamOnce   | x if S : RangeStreamOnce | x if S : RangeStreamOnce         |                          | x if S : RangeStreamOnce |
| trait DefaultPositioned |                          | x                                |                          |                          |
|   ↳ type Positioner     |                          |  IndexPositioner                 |                          |                          |
```
### Best practices

First you need to answer a few questions about your data source `s`.

 - Is your data source neither a slice nor an `Iterator` nor a `Read`?
    - You could implement `StreamOnce` and siblings, but I recommend
      implementing `Iterator` or `Read` instead and use the wrappers:
    - `let s = IteratorStream::new(i);` if your source `i` is an `Iterator +
      Clone`.
    - `let s = BufferedStream::new(IteratorStream::new(i), 100);` if your
      source `i` is an `Iterator`.
    - `let s = BufferedStream::new(State::new(ReadStream::new(r)), 100);` if
      your source `r` is an `io::Read`.

 - Do you want nice human readable errors? (and you have `std` available)
    - `let s = easy::Stream(s);` if ` s : &str` or `s : &[T]`.
      - Also use `map_err(|e| e.translate_position(s))` on all parser errors
    - `let s = easy::Stream(State::new(s));` if `s : &str` and if you are
      interested in line/column information.
    - `let s =
      BufferedStream::new(easy::Stream(State::new(IteratorStream::new(i))),
      100);` if `i : Iterator`
    - `let s =
      BufferedStream::new(easy::Stream(State::new(ReadStream::new(r))),
      100);` if `r : Read`

 - Is your data source `s : &[T]` a slice but cloning `T` is too much
   overhead?
    - Use `SliceStream(s)` instead of `s` (and combine like
      `easy::Stream(SliceStream(s))`)

 - Is your data arriving in parts?
    - Does waiting for more data and retrying the parsing from the beginning
      is too much overhead? (> 1kb object size, more than 100 objects per
      second)
       - Use `PartialStream(s)`. The tradeoff is that the parser output
         can't borrow from the input as we generally must assume the input
         to be shortlived.

