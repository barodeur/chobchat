let tap = (promise, fn) => {
  promise->Promise.thenResolve(v => {
    fn(v)
    v
  })
}
