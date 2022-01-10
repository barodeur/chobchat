Jest.init()

Jest.describe("Device", () => {
  Jest.describe(".generateId", () => {
    Jest.test("it generate an id", () => {
      let re = %re("/dev_[123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz]{22}/")
      Jest.expect(re->Js.Re.test_(Device.generateId()))->Jest.toEqual(true)
    })
  })
})
