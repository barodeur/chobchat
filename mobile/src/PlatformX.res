type adapter =
  | Web
  | Server
  | Mobile
  | Unknown

let currentAdapter = switch ReactNative.Platform.os {
| os if os === ReactNative.Platform.ios => Mobile
| os if os === ReactNative.Platform.android => Mobile
| os if os === ReactNative.Platform.web =>
  if %raw(`typeof window === "undefined"`) {
    Server
  } else {
    Web
  }
| _ => Unknown
}
