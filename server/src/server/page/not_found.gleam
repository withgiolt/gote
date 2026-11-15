import server/layout.{NoScript}

pub fn render() -> String {
  layout.document(
    title: "Not found",
    script: NoScript,
    body: layout.page(
      path: "",
      title: "Not found",
      intro: ["There's no page here."],
      content: [],
      sources: ["server/src/server/router.gleam"],
    ),
  )
}
