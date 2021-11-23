let url = Recoil.atomWithEffects({
  key: "Linking/Url",
  default: None,
  effects_UNSTABLE: [
    ({setSelf}) => {
      ElectronRendererIPC.onMessage((_, msg) => {
        switch msg {
        | URLOpened(url) => setSelf(_ => Some(url))
        | _ => ()
        }
      })
      None
    },
  ],
})

let useURL = () => Recoil.useRecoilValue(url)
