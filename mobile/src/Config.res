module Web = {
  @val @scope(("process", "env")) @return(nullable)
  external homeserverUrl: option<string> = "NEXT_PUBLIC_HOMESERVER_URL"
  @val @scope(("process", "env")) @return(nullable)
  external roomId: option<string> = "NEXT_PUBLIC_ROOM_ID"
}

module Mobile = {
  @module("expo-constants") @scope(("default", "manifest", "extra")) @return(nullable)
  external homeserverUrl: option<string> = "homeserverUrl"
  @module("expo-constants") @scope(("default", "manifest", "extra")) @return(nullable)
  external roomId: option<string> = "roomId"
}

let homeserverUrl = switch PlatformX.currentAdapter {
| Web => Web.homeserverUrl
| Mobile => Mobile.homeserverUrl
| _ => None
}

let roomId = switch PlatformX.currentAdapter {
| Web => Web.roomId
| Mobile => Mobile.roomId
| _ => None
}
