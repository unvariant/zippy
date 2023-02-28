# zippy
An iterator library for Zig.

## Interface
This library shares the same interface with the Rust Iterator trait and iter crate. The behavior differs slightly due to restrictions in Zig. If you want an iterator to be still usable after a consuming function you must call `.byRef()` on it first to borrow the iterator by reference. See [examples](./examples) for a more in depth explanation.

## Zig Version
Currently the library supports `0.10.0`, and I will update it to use `0.11.0` once it becomes stable.

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
- [ ] cycle
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
- [x] empty
- [ ] from_fn
- [x] once
- [ ] once_with
- [x] repeat
- [ ] repeat_with

## Custom Iterator methods
These are methods that are not in Rust, but I feel should be included for Zig.

### Drop methods
There exists a `Drop` variant of every iterator method that could possibly discard data. They take an extra argument, which is a user defined destructor that runs on any iterator elements that would be discarded. Note that if an element is not evaluated the destructor will not be called on that element.
- [ ] filterDrop
- [ ] filterMapDrop
- [ ] skipDrop
- [ ] skipWhileDrop

### Misc
- [x] first
  - consumes the iterator, and returns the first element

## Performance
I have not attempted to profile this library at all (although I am planning to soon), so I can not make any guarantees about performance.