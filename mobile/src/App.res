@react.component
let make = () => {
  <RescriptRelay.Context.Provider environment=RelayEnv.environment>
    <div>
      <React.Suspense fallback={React.string("loading...")}> <Profile /> </React.Suspense>
    </div>
  </RescriptRelay.Context.Provider>
}
