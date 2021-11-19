@module("expo-splash-screen") external hideAsync: unit => Promise.t<bool> = "hideAsync"
@module("expo-splash-screen")
external preventAutoHideAsync: unit => Promise.t<bool> = "preventAutoHideAsync"
