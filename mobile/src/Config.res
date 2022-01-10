type t = {
  homeserverUrl: string,
  roomId: string,
}

module Mobile = {
  @module("expo-constants") @scope(("default", "manifest")) external config: t = "extra"
}

module Electron = {
  @val @scope(("process", "env", "APP_MANIFEST")) external config: t = "extra"
}

let jotaiAtom = Jotai.Atom.make(
  switch PlatformX.platform {
  | Mobile(_) => Mobile.config->Some
  | Web(Electron) => Electron.config->Some
  | _ => None
  },
)
