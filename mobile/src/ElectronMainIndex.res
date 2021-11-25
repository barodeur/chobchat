open Electron__Main

@val @scope(("process", "env")) external nodeEnv: Js.Undefined.t<string> = "NODE_ENV"
@val @scope(("process", "env"))
external electronWebpackWDSPort: Js.Undefined.t<string> = "ELECTRON_WEBPACK_WDS_PORT"
@val @scope("process") external platform: string = "platform"

let protocol = "chobchat"

let boolRes = App.setAsDefaultProtocolClient(protocol)

let isDevelopment =
  nodeEnv->Js.Undefined.toOption->Option.mapWithDefault(false, env => env != "production")

let mainWindow = ref(None)

let baseUrl = switch (
  isDevelopment,
  electronWebpackWDSPort->Js.Undefined.toOption,
  %external(__dirname),
) {
| (true, Some(port), _) => Some(`http://localhost:${port}`)
| (false, _, Some(dirname)) => Some(`file://${Node.Path.join([dirname, "index.html"])}`)
| _ => None
}

let makeMainWindow = () => {
  let window = BrowserWindow.make(
    BrowserWindow.config(
      ~width=400,
      ~height=800,
      ~contextIsolation=false,
      ~webPreferences=BrowserWindow.webPreferencesConfig(~nodeIntegration=true, ()),
      (),
    ),
  )

  if isDevelopment {
    window->BrowserWindow.webContents->WebContents.openDevTools
  }

  baseUrl->Option.map(url => window->BrowserWindow.loadURL(url))->ignore

  window
  ->BrowserWindow.webContents
  ->WebContents.on("devtools-opened", () => {
    window->BrowserWindow.focus
    Immediate.set(() => window->BrowserWindow.focus)->ignore
  })

  window
}

app->App.on("window-all-closed", () => {
  switch platform->Js.Undefined.toOption {
  | Some("darwin") => app->App.quit
  | _ => ()
  }
})

app->App.on("activate", () => {
  if mainWindow.contents == None {
    mainWindow.contents = Some(makeMainWindow())
  }
})

app->App.on("ready", () => {
  mainWindow.contents = Some(makeMainWindow())
})

ElectronMainIPC.onMessage((e, m) => {
  switch m {
  | OpenExternal(url) => {
      Shell.openExternal(url)->ignore
      e->ElectronMainIPC.Event.setReturnValue(Nothing)
      ()
    }
  | _ => ()
  }
})

let isLocked = App.requestSingleInstanceLock()
if !isLocked {
  App.exit()
}

let processUrl = url => {
  switch (mainWindow.contents, baseUrl) {
  | (Some(win), Some(baseURL)) =>
    win->BrowserWindow.loadURL(
      url->Js.String2.replaceByRe(Js.Re.fromString(`^${protocol}:[/]{0,2}`), baseURL),
    )
  | _ => ()
  }
}

switch platform {
| "darwin" =>
  App.onOpenUrl((event, url) => {
    event->Event.preventDefault
    processUrl(url)
  })
| "linux" =>
  App.onSecondInstance((_, argv) => {
    argv
    ->Belt.Array.get(argv->Belt.Array.length - 1)
    ->Option.map(url =>
      if url->Js.String2.startsWith(`${protocol}:`) {
        processUrl(url)
      }
    )
    ->ignore
  })
| _ => ()
}
