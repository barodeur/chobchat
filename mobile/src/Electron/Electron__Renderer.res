type event

module MakeIPC = (
  T: {
    type message
  },
) => {
  type ipc

  @val @module("./electron") external ipc: ipc = "ipcRenderer"

  @send external sendSync_: (ipc, @as("message") _, T.message) => T.message = "sendSync"
  let sendSync = msg => ipc->sendSync_(msg)

  @send external send: (ipc, @as("message") _, T.message) => unit = "send"

  @send external onMessage_: (ipc, @as("message") _, (event, T.message) => unit) => unit = "on"
  let onMessage = handler => ipc->onMessage_(handler)
}
