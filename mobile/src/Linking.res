let useURL = switch PlatformX.platform {
| Web(Electron) => ElectronLinking.useURL
| _ => ExpoLinking.useURL
}
