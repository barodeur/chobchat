require('react-native-gesture-handler');
const { registerRootComponent } = require('expo');
const { make: App } = require('./src/App.bs');

registerRootComponent(App);
