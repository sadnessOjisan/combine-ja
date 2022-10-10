
## What is combine?

`combine` is a parser combinator library. Let's explain that in two steps.

A "parser" is an algorithm that turns a string of input (for example a `&str` or `&[u8]`) into some output (for example `(i32, Vec<i32>)`) according to a grammar.

A "combinator" refers to the ability to *combine* multiple smaller parsers
into a larger one. In `combine` this is done simply by defining and calling
functions which take one or more parsers as arguments and returns a new
parser. This is how it looks like:

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

`take_while1`, `range` and `sep_by` are parser combinators from the
`combine` library. `tool` and `tools` are parsers produced from those
combinators. The latter is also the final parser.

## Tutorial

Learn `combine` with the not so quick [Quickstart Tutorial](Tutorial).

## Inner machinery

Every parser in every language needs roughly these four things to work:
 - [The data to parse or a way to obtain that data](Input-Machinery)
 - [A definition of the format to parse](Parser-Trait)
 - A way of gathering and returning the information it has found
 - [A way to notify about Errors during parsing](Error-Handling)

It may also support one or more of these extra functionalities
 - Resume parsing / streaming of input data
 - Giving location information of input data tokens (e.g. line, column for text input)

As `combine` attempts to be as flexible as possible in what can be used as
input there can be quite a few traits to implement but most of the
high-level use should only need to concern itself with a few of them (namely
`Stream`, `RangeStream` and `FullRangeStream`, the latter two only for
zero-copy parsing).

The linked chapters describe the `combine` way of these things and why they
are the way they are. This helps a lot understanding error messages and
dealing with sticks and stones.

## Alternatives

For reference, here are some alternatives in the rust ecosystem:

 - [nom](https://crates.io/crates/nom)
 - [pest](https://crates.io/crates/pest)
 - [lalrpop](https://crates.io/crates/lalrpop)

All parser libraries come with their own trade offs, so choose wisely
:smile: .
