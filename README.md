# zippy
An iterator library for Zig.

## Interface
This library shares the same interface with the Rust Iterator trait and iter crate. The behavior differs slightly due to restrictions in Zig. If you want an iterator to be still usable after a consuming function you must call `.byRef()` on it first to borrow the iterator by reference. See [examples](./examples) for a more in depth explanation.

## Goals
- [x] iterator chain calling
    - ```it.take(10).chain(other).skip(3)```
- [x] zero heap allocation
- [x] simple interface
- [x] not too much internal boilerplate
- [ ] implement the functions of the Rust Iterator trait

## Iterator
- [x] all
- [x] any
- [x] by_ref
- [x] chain
- [ ] cloned
- [ ] cmp
- [x] collect
- [ ] copied
- [x] count
- [x] enumerate
- [ ] eq
- [x] filter
- [x] filter_map
- [x] find
- [ ] find_map
- [ ] flat_map
- [ ] flatten
- [x] fold
- [x] for_each
- [ ] fuse
- [ ] ge
- [ ] gt
- [ ] inspect
- [x] last
- [ ] le
- [ ] lt
- [x] map
- [ ] map_while
- [ ] max
- [ ] max_by
- [ ] max_by_key
- [ ] min
- [ ] min_by
- [ ] min_by_key
- [ ] ne
- [x] nth
- [ ] partial_cmp
- [ ] partition
- [ ] peekable
- [x] position
- [ ] product
- [x] reduce
- [ ] rev
- [ ] rposition
- [ ] scan
- [ ] size_hint
- [x] skip
- [x] skip_while
- [x] step_by
- [ ] sum
- [x] take
- [x] take_while
- [ ] try_fold
- [ ] try_for_each
- [ ] unzip
- [x] zip

## iter
- [ ] empty
- [ ] from_fn
- [ ] once
- [ ] once_with
- [ ] repeat
- [ ] repeat_with

## Custom Iterator methods
- first
  - consumes the iterator, and returns the first element
- filterDrop
  - filters the iterator using a predicate, and calls a user passed destructor on elements that are filtered out

## Performance
I have not attempted to profile this library at all (although I am planning to soon), so I can not make any guarantees about performance.