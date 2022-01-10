type r<'a> = {value: 'a, loading: bool}

let useAsyncMemo1 = (fn, deps) => {
  let promise = React.useRef(Promise.resolve())
  let (value, setValue) = React.useState(_ => None)
  let (loading, setLoading) = React.useState(_ => false)

  React.useEffect1(() => {
    promise.current =
      promise.current->Promise.then(() => {
        setLoading(_ => true)
        fn()->Promise.thenResolve(value => {
          setValue(_ => Some(value))
          setLoading(_ => false)
        })
      })
    None
  }, deps)

  {value: value, loading: loading}
}
