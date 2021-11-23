open Electron__Main

@val @scope(("process", "env")) external nodeEnv: Js.Undefined.t<string> = "NODE_ENV"
@val @scope(("process", "env"))
external electronWebpackWDSPort: Js.Undefined.t<string> = "ELECTRON_WEBPACK_WDS_PORT"
@val @scope("process") external platform: Js.Undefined.t<string> = "platform"

let boolRes = App.setAsDefaultProtocolClient("chobchat")

let isDevelopment =
  nodeEnv->Js.Undefined.toOption->Option.mapWithDefault(false, env => env != "production")

let mainWindow = ref(None)

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

  if isDevelopment {
    electronWebpackWDSPort
    ->Js.Undefined.toOption
    ->Option.mapWithDefault((), v => window->BrowserWindow.loadURL(`http://localhost:${v}`))
  } else {
    %external(__dirname)->Option.mapWithDefault((), dirname => {
      window->BrowserWindow.loadURL(`file://${Node.Path.join([dirname, "index.html"])}`)
    })
  }

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

App.onOpenUrl((event, url) => {
  event->Event.preventDefault
  switch mainWindow.contents {
  | Some(win) =>
    win->BrowserWindow.webContents->ElectronMainIPC.WebContents.sendMessage(URLOpened(url))
  | _ => ()
  }
})
