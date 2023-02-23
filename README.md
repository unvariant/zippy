# iter
An iterator library for Zig.

This started out as a toy project to gain more familiarity with Zig, and when I initially started on this project, I thought I would be finished within a day, and ended up spending more than a week on it.

## Goals
- [x] iterator chain calling
    - ```it.take(10).chain(other).drop(3)```
- [x] zero heap allocation
- [x] simple interface
- [x] not too much internal boilerplate

## Stable
- [x] all
- [x] any
- [x] by_ref
- [x] chain
- [ ] cloned
- [ ] cmp
- [x] collect
- [ ] copied
- [ ] count
- [ ] enumerate
- [ ] eq
- [x] filter
- [ ] filter_map
- [ ] find
- [ ] find_map
- [ ] flat_map
- [ ] flatten
- [x] fold
- [x] for_each
- [ ] fuse
- [ ] ge
- [ ] gt
- [ ] inspect
- [ ] last
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
- [ ] nth
- [ ] partial_cmp
- [ ] partition
- [ ] peekable
- [ ] position
- [ ] product
- [x] reduce
- [ ] rev
- [ ] rposition
- [ ] scan
- [ ] size_hint
- [x] skip
- [ ] skip_while
- [ ] step_by
- [x] sum
- [x] take
- [ ] take_while
- [ ] try_fold
- [ ] try_for_each
- [ ] unzip
- [ ] zip

## Performance
TODO