let autoUpdater = ElectronUpdater.autoUpdater

let checkForUpdatesAndNotify = () => autoUpdater->ElectronUpdater.checkForUpdatesAndNotify
autoUpdater->ElectronUpdater.setLogger(ElectronLog.log)

module AutoUpdater = {
  type t = ElectronUpdater.autoUpdater
  type logger
  type transports
  type file
  type level

  @get external logger: t => logger = "logger"
  @get external transports: logger => transports = "transports"
  @get external file: transports => file = "file"
  @set external setLevel: (file, string) => unit = "level"

  autoUpdater->logger->transports->file->setLevel("info")
}
