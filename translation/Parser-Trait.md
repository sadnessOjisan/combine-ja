
From the rust code viewpoint, a parser is a type that implements the
`Parser` trait.


```rust
// ommitted/shortened some trait bounds
// P2 is always another Parser<Input = I> with the same input
// ERR is <I as StreamOnce>::Error

pub trait Parser {
    type Input: Stream;         // abbreviated as I
    type Output;                // abbreviated as O
    type PartialState: Default; // abbreviated as PS

    // ENTRY POINTS

    fn easy_parse<I>(&mut self, input: I2 ) -> Result<(O, I2), ParseError<I>> { ... }
    fn parse(&mut self, input: I ) -> Result<(O, I), <I as StreamOnce>::Error> { ... }
    fn parse_with_state(&mut self, input: &mut I, state: &mut PS ) -> Result<O, <I as StreamOnce>::Error> { ... }

    // COMBINING WITH OTHER PARSERS (or with itself)

    fn with<P2>(self, p: P2) -> With<Self, P2>  { ... }
    fn skip<P2>(self, p: P2) -> Skip<Self, P2> { ... }
    fn and<P2>(self, p: P2) -> (Self, P2) { ... }
    fn or<P2>(self, p: P2) -> Or<Self, P2> where P2 and P1 have the same Output { ... }
    fn left<R>(self) -> Either<Self, R> where R: Parser<Input = I, Output = O> { ... }
    fn right<L>(self) -> Either<L, Self> where L: Parser<Input = I, Output = O> { ... }

    // MAPPING THE OUTPUT

    fn then<N, F>(self, f: impl FnMut(O) -> impl Parser) -> Then<Self, F> { ... }
    fn then_partial<N, F>(self, f: FnMut(&mut O) -> impl Parser) -> ThenPartial<Self, F> { ... }
    fn map<F, B>(self, f: impl FnMut(O) -> B) -> Map<Self, F> { ... }
    fn flat_map<F, B>(self, f: impl FnMut(O) -> Result<B, ERR>) -> FlatMap<Self, F> { ... }
    fn and_then<F, O, E, I>(self, f: impl FnMut(O) -> Result<O, ERR>) -> AndThen<Self, F>  { ... }

    // MANIPULATING ERROR MESSAGES    

    fn message<S>(self, msg: impl Into<Info<>>) -> Message<Self> { ... }
    fn expected<S>(self, msg: impl Into<Info<>>) -> Expected<Self> { ... }
    fn silent(self) -> Silent<Self> { ... }

    // MISCELLANEOUS

    fn by_ref(&mut self) -> &mut Self { ... }
    fn boxed<'a>(self) -> Box<dyn Parser<> + 'a> { ... }

    // INTERNAL API STUFF / IMPLEMENTING PARSERS YOURSELF

    fn iter(self, input: &mut I ) -> Iter<Self, PS, FirstMode> { ... }
    fn partial_iter<'a, 's, M>(self, mode: M, input: &'a mut I, partial_state: &'s mut PS ) -> Iter<'a, Self, &'s mut PS, M> where M: ParseMode  { ... }
    fn parse_stream(&mut self, input: &mut I ) -> ParseResult<O, I> { ... }
    fn parse_stream_consumed(&mut self, input: &mut I ) -> ConsumedResult<O, I> { ... }
    fn parse_stream_consumed_partial(&mut self, input: &mut I, state: &mut PS ) -> ConsumedResult<O, I> { ... }
    fn parse_lazy(&mut self, input: &mut I ) -> ConsumedResult<O, I> { ... }
    fn parse_first(&mut self, input: &mut I, state: &mut PS ) -> ConsumedResult<O, I> { ... }
    fn parse_partial(&mut self, input: &mut I, state: &mut PS ) -> ConsumedResult<O, I> { ... }
    fn add_error(&mut self, _error: &mut Tracked<<I as StreamOnce>::Error> ) { ... }

}

```