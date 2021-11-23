type web = Server | Browser | Electron
type mobile = Android | Ios
type t =
  | Web(web)
  | Mobile(mobile)
  | Unknown

let platform = switch ReactNative.Platform.os {
| os if os === ReactNative.Platform.ios => Mobile(Ios)
| os if os === ReactNative.Platform.android => Mobile(Android)
| os if os === ReactNative.Platform.web =>
  if %raw(`typeof window === "undefined"`) {
    Web(Server)
  } else if %raw(`typeof process == "object" && process.versions && process.versions.electron`) {
    Web(Electron)
  } else {
    Web(Browser)
  }
| _ => Unknown
}
