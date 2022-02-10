// open ElectronUpdater

let autoUpdater = ElectronUpdater.autoUpdater

let checkForUpdatesAndNotify = () => autoUpdater->ElectronUpdater.checkForUpdatesAndNotify
autoUpdater->ElectronUpdater.setLogger(ElectronLog.log)
%%raw(`autoUpdater.logger.transports.file.level = "info"`)
