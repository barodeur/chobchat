type t = {
  homeserverUrl: string,
  roomId: string,
}

let recoilAtom: Recoil.readWrite<option<t>> = Recoil.atom({
  key: "Config",
  default: None,
})

module Mobile = {
  @module("expo-constants") @scope(("default", "manifest")) external config: t = "extra"
}

let initialConfig = switch PlatformX.platform {
| Mobile(_) => Mobile.config->Some
| _ => None
}
