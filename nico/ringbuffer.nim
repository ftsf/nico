import math

type
  RingBuffer*[T] = object
    data*: seq[T]
    head*, tail*: int
    size*, length*: int

proc initRingBuffer*[T](length: int): RingBuffer[T] =
  let s = newSeq[T](length)
  RingBuffer[T](data: s, head: 0, tail: -1, size: 0, length: length)

template adjustHead(b: untyped): untyped =
  b.head = (b.length + b.tail - b.size + 1) mod b.length

template adjustTail(b, change: untyped): untyped =
  b.tail = (b.tail + change) mod b.length

proc add*[T](b: var RingBuffer[T], data: openArray[T]) =
  for item in data:
    b.adjustTail(1)
    b.data[b.tail] = item
  b.size = min(b.size + len(data), b.length)
  b.adjustHead()

proc add*[T](b: var RingBuffer[T], data: T) =
  b.adjustTail(1)
  b.data[b.tail] = data
  b.size = min(b.size + 1, b.length)
  b.adjustHead()

func idx*[T](b: RingBuffer[T], i: int): int =
  if i < 0:
    # index from newest entry
    # -1 == newest entry
    floorMod((b.tail + (i + 1)), b.length)
  else:
    floorMod((i + b.head), b.length)

proc `[]`*[T](b: RingBuffer[T], i: int): T =
  b.data[b.idx(i)]

proc `[]=`*[T](b: var RingBuffer[T], i: int, item: T) {.raises: [IndexDefect].} =
  ## Set an item at index (adjusted)
  let idx = b.idx(i)
  if idx == b.size: inc(b.size)
  elif idx > b.size: raise newException(IndexDefect, "Index " & $idx & " out of bound")

proc len*[T](b: RingBuffer[T]): int =
  return b.length

when isMainModule:
  import unittest

  suite "ringbuffer":
    test "index":
      var rb = newRingBuffer[int](3)
      rb.add(0)
      rb.add(1)
      rb.add(2)
      check(rb[0] == 0)
      check(rb[1] == 1)
      check(rb[2] == 2)
      rb.add(3)
      check(rb[0] == 1)
      check(rb[1] == 2)
      check(rb[2] == 3)

    test "revIndex":
      var rb = newRingBuffer[int](3)
      rb.add(0)
      rb.add(1)
      rb.add(2)
      check(rb[-1] == 2)
      check(rb[-2] == 1)
      check(rb[-3] == 0)
      rb.add(3)
      check(rb[-1] == 3)
      check(rb[-2] == 2)
      check(rb[-3] == 1)
