type autoUpdater

@val @module("electron-updater") external autoUpdater: autoUpdater = "autoUpdater"
@send external checkForUpdatesAndNotify: autoUpdater => unit = "checkForUpdatesAndNotify"
@set external setLogger: (autoUpdater, ElectronLog.log) => unit = "logger"
