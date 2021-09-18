/* UserProfile.res */
module Query = %relay(`
  query ProfileQuery {
    user {
      id
    }
  }
`)

@react.component
let make = () => {
  let queryData = Query.use(~variables=(), ())

  switch queryData.user {
  | Some(user) =>
    <div>
      {React.string(
        switch user.id {
        | Some(id) => id
        | None => "No ID"
        },
      )}
    </div>
  | None => React.null
  }
}
