import dom
import jsffi

type
  EventEmitter* {.importjs:"EventEmitter".} = ref object of RootObj
  Peer* {.importjs:"Peer".} = ref object of EventEmitter
    connections*: seq[DataConnection]
  PeerOptions* = object
    debug*: int
  DataConnection* {.importjs:"DataConnection".} = ref object of EventEmitter
    peer*: cstring

proc newPeer*(): Peer {.importjs:"new Peer(@)".}
proc newPeer*(id: cstring): Peer {.importjs:"new Peer(@)".}
proc newPeer*(options: PeerOptions): Peer {.importjs:"new Peer(@)".}
proc newPeer*(id: cstring, options: PeerOptions): Peer {.importjs:"new Peer(@)".}
#proc on*(self: Peer, event: string, callback: proc(data: string), context: JsObject = nil) {.importjs:"#.on(@)".}
proc addListener*(self: EventEmitter, event: string, fn: proc(data: string), context: JsObject = nil, once: bool = false): EventEmitter {.importjs:"#.addListener(@)", discardable.}
proc on*(self: Peer, event: cstring, callback: proc(data: JsObject), context: JsObject = nil): EventEmitter {.importjs:"#.on(@)", discardable.}

proc connect*(self: Peer, id: cstring): DataConnection {.importjs:"#.connect(@)".}
proc reconnect*(self: Peer) {.importjs:"#.reconnect(@)".}
proc on*(self: DataConnection, event: cstring, callback: proc(data: cstring)) {.importjs:"#.on(@)".}
proc send*(self: DataConnection, data: cstring) {.importjs:"#.send(@)".}
