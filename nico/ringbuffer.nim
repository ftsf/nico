import macros

type
  RingBuffer*[T] = object
    data: seq[T]
    head, tail: int
    size*, length*: int


proc newRingBuffer*[T](length: int): RingBuffer[T] =
  let s = newSeq[T](length)
  RingBuffer[T](data: s, head: 0, tail: -1, size: 0, length: length)

template adjustHead(b: expr): stmt =
  b.head = (b.length + b.tail - b.size + 1) mod b.length

template adjustTail(b, change: expr): stmt =
  b.tail = (b.tail + change) mod b.length

proc add*[T](b: var RingBuffer[T], data: openArray[T]) =
  for item in data:
    b.adjustTail(1)
    b.data[b.tail] = item
  b.size = min(b.size + len(data), b.length)
  b.adjustHead()

proc `[]`*[T](b: RingBuffer[T], idx: int): T {.inline} =
  b.data[(idx + b.head) mod b.length]

proc `[]=`*[T](b: var RingBuffer[T], idx: int, item: T) {.raises: [IndexError].} =
  ## Set an item at index (adjusted)
  if idx == b.size: inc(b.size)
  elif idx > b.size: raise newException(IndexError, "Index " & $idx & " out of bound")
