type app
type event
type browserWindow
type webContents
type shell

@val @module("./electron.electron") external app: app = "app"
@val @module("./electron.electron") external shell: shell = "shell"

module Event = {
  type t = event

  @send external preventDefault: t => unit = "preventDefault"
}

module App = {
  type t = app

  @send external on: (app, string, unit => unit) => unit = "on"
  @send external quit: app => unit = "quit"

  @send external setAsDefaultProtocolClient_: (app, string) => bool = "setAsDefaultProtocolClient"
  let setAsDefaultProtocolClient = protocol => app->setAsDefaultProtocolClient_(protocol)

  @send external onOpenUrl_: (app, @as("open-url") _, (event, string) => unit) => unit = "on"
  let onOpenUrl = handler => app->onOpenUrl_(handler)
}

module WebContents = {
  type t = webContents
  @send external openDevTools: t => unit = "openDevTools"
  @send external on: (t, string, unit => unit) => unit = "on"
}

module BrowserWindow = {
  type t = browserWindow

  @deriving(abstract)
  type webPreferencesConfig = {@optional nodeIntegration: bool}

  @deriving(abstract)
  type config = {
    @optional width: int,
    @optional height: int,
    @optional contextIsolation: bool,
    @optional webPreferences: webPreferencesConfig,
  }
  @new @module("./electron.electron") external make: config => t = "BrowserWindow"
  @get external webContents: browserWindow => webContents = "webContents"
  @send external loadURL: (t, string) => unit = "loadURL"
  @send external focus: t => unit = "focus"
}

module Shell = {
  type t = shell
  @send external openExternal_: (shell, string) => Promise.t<unit> = "openExternal"
  let openExternal = url => shell->openExternal_(url)
}

module MakeIPC = (
  T: {
    type message
  },
) => {
  type event
  type msg_ = T.message

  module Event = {
    type t = event

    @send external reply: (t, @as("message") _, msg_) => unit = "reply"
    @set external setReturnValue: (t, msg_) => unit = "returnValue"
  }

  type ipc

  @module("./electron.electron") external ipc: ipc = "ipcMain"

  @send external onMessage_: (ipc, @as("message") _, (event, msg_) => unit) => unit = "on"
  let onMessage = handler => ipc->onMessage_(handler)

  module WebContents = {
    @send external sendMessage: (WebContents.t, @as("message") _, msg_) => unit = "send"
  }
}
